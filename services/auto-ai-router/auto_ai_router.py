"""Small OpenAI-compatible orchestrator for the local two-host AI stack."""

from __future__ import annotations

import base64
import copy
import json
import logging
import os
import re
import time
import uuid
from dataclasses import dataclass
from typing import Any, AsyncIterator

import httpx
from fastapi import FastAPI, Request
from fastapi.responses import JSONResponse, Response, StreamingResponse


LOGGER = logging.getLogger("auto-ai-router")
VALID_ROUTES = {"reasoning", "vision_reasoning", "coder", "vision_coder"}
IMAGE_TYPES = {"image", "image_url", "input_image"}
MISSING = object()

ROUTER_PROMPT = """You are a routing sensor, not the answering assistant.
Choose exactly one route for the user's request:
- reasoning: general questions, analysis, planning, debugging, review
- coder: repository work, code generation, patches, refactoring, tests
- vision_reasoning: an image plus general analysis or debugging
- vision_coder: an image plus code or repository changes

Return only one compact JSON object with keys route, confidence, and reason.
confidence must be a number from 0 to 1. Never answer the user.
"""

VISION_PROMPT = """You are a visual debugging sensor for a senior reasoning model.
Analyze every attached image carefully.

Extract:
- exact visible errors and warnings,
- terminal commands and terminal output,
- filenames and paths,
- package and service names,
- application and window state,
- suspicious UI state,
- anything unreadable or uncertain.

Transcribe visible technical text accurately. Do not invent unreadable text.
Mark uncertainty explicitly. Return a concise structured VISION REPORT.
"""


@dataclass(frozen=True)
class Settings:
    litellm_base_url: str = "http://127.0.0.1:4000/v1"
    litellm_api_key: str = "auto-internal"
    router_model: str = "router"
    vision_model: str = "vision"
    reasoning_model: str = "reasoning"
    coder_model: str = "coder"
    router_timeout: float = 15.0
    vision_timeout: float = 180.0
    final_timeout: float = 900.0
    router_confidence: float = 0.65

    @classmethod
    def from_environment(cls) -> "Settings":
        return cls(
            litellm_base_url=os.getenv(
                "AUTO_AI_LITELLM_BASE_URL", cls.litellm_base_url
            ).rstrip("/"),
            litellm_api_key=(
                os.getenv("AUTO_AI_LITELLM_API_KEY")
                or os.getenv("LITELLM_MASTER_KEY")
                or cls.litellm_api_key
            ),
            router_model=os.getenv("AUTO_AI_ROUTER_MODEL", cls.router_model),
            vision_model=os.getenv("AUTO_AI_VISION_MODEL", cls.vision_model),
            reasoning_model=os.getenv("AUTO_AI_REASONING_MODEL", cls.reasoning_model),
            coder_model=os.getenv("AUTO_AI_CODER_MODEL", cls.coder_model),
            router_timeout=float(
                os.getenv("AUTO_AI_ROUTER_TIMEOUT", str(cls.router_timeout))
            ),
            vision_timeout=float(
                os.getenv("AUTO_AI_VISION_TIMEOUT", str(cls.vision_timeout))
            ),
            final_timeout=float(
                os.getenv("AUTO_AI_FINAL_TIMEOUT", str(cls.final_timeout))
            ),
            router_confidence=float(
                os.getenv("AUTO_AI_ROUTER_CONFIDENCE", str(cls.router_confidence))
            ),
        )


@dataclass
class PreparedRequest:
    payload: dict[str, Any]
    target_model: str
    route: str
    image_count: int
    router_ms: int
    vision_ms: int
    fallback: bool


def _request_id(value: str | None) -> str:
    if value and re.fullmatch(r"[A-Za-z0-9._:-]{1,64}", value):
        return value
    return uuid.uuid4().hex[:12]


def _looks_like_image_data(value: str) -> str | None:
    if value.startswith("data:image/"):
        return value
    try:
        prefix = base64.b64decode(value[:48], validate=True)
    except (ValueError, base64.binascii.Error):
        return None
    if prefix.startswith(b"\x89PNG\r\n\x1a\n"):
        return f"data:image/png;base64,{value}"
    if prefix.startswith(b"\xff\xd8\xff"):
        return f"data:image/jpeg;base64,{value}"
    if prefix.startswith(b"RIFF") and prefix[8:12] == b"WEBP":
        return f"data:image/webp;base64,{value}"
    return None


def _normalize_image_node(value: Any) -> dict[str, Any] | None:
    if isinstance(value, str):
        data_uri = _looks_like_image_data(value)
        return {"type": "image_url", "image_url": {"url": data_uri}} if data_uri else None
    if not isinstance(value, dict):
        return None

    node_type = value.get("type")
    if node_type == "image_url" and "image_url" in value:
        return copy.deepcopy(value)
    if node_type == "input_image":
        image_url = value.get("image_url") or value.get("url")
        if image_url:
            return {"type": "image_url", "image_url": copy.deepcopy(image_url)}

    source = value.get("source")
    if isinstance(source, dict) and source.get("type") == "base64":
        media_type = source.get("media_type", "image/png")
        data = source.get("data")
        if isinstance(data, str):
            return {
                "type": "image_url",
                "image_url": {"url": f"data:{media_type};base64,{data}"},
            }

    if node_type in IMAGE_TYPES or "image_url" in value:
        image_url = value.get("image_url") or value.get("url")
        if isinstance(image_url, (str, dict)):
            return {"type": "image_url", "image_url": copy.deepcopy(image_url)}

    for key in ("image", "data"):
        raw = value.get(key)
        if isinstance(raw, str):
            data_uri = _looks_like_image_data(raw)
            if data_uri:
                return {"type": "image_url", "image_url": {"url": data_uri}}
    return None


def collect_images(value: Any) -> list[dict[str, Any]]:
    normalized = _normalize_image_node(value)
    if normalized is not None:
        return [normalized]
    if isinstance(value, list):
        images: list[dict[str, Any]] = []
        for item in value:
            images.extend(collect_images(item))
        return images
    if isinstance(value, dict):
        images = []
        for item in value.values():
            images.extend(collect_images(item))
        return images
    return []


def _strip_images(value: Any) -> Any:
    if _normalize_image_node(value) is not None:
        return MISSING
    if isinstance(value, list):
        stripped = []
        for item in value:
            clean = _strip_images(item)
            if clean is not MISSING:
                stripped.append(clean)
        return stripped
    if isinstance(value, dict):
        stripped_dict = {}
        for key, item in value.items():
            clean = _strip_images(item)
            if clean is not MISSING:
                stripped_dict[key] = clean
        return stripped_dict
    return copy.deepcopy(value)


def strip_images_from_messages(messages: list[dict[str, Any]]) -> list[dict[str, Any]]:
    clean_messages: list[dict[str, Any]] = []
    for message in messages:
        clean = _strip_images(message)
        if clean is MISSING:
            continue
        if isinstance(clean, dict) and clean.get("content") == []:
            clean["content"] = ""
        clean_messages.append(clean)
    return clean_messages


def _content_text(content: Any) -> str:
    if isinstance(content, str):
        return content if not content.startswith("data:image/") else ""
    if isinstance(content, list):
        parts = []
        for part in content:
            if isinstance(part, dict) and part.get("type") in {"text", "input_text"}:
                text = part.get("text")
                if isinstance(text, str):
                    parts.append(text)
        return "\n".join(parts)
    return ""


def latest_user_text(messages: list[dict[str, Any]]) -> str:
    for message in reversed(messages):
        if message.get("role") == "user":
            return _content_text(message.get("content"))[-8000:]
    return ""


def append_vision_report(
    messages: list[dict[str, Any]], report: str
) -> list[dict[str, Any]]:
    addition = f"<vision_report>\n{report}\n</vision_report>"
    for message in reversed(messages):
        if message.get("role") != "user":
            continue
        content = message.get("content")
        if isinstance(content, list):
            content.append({"type": "text", "text": addition})
        elif isinstance(content, str):
            message["content"] = f"{content}\n\n{addition}" if content else addition
        else:
            message["content"] = addition
        return messages
    messages.append({"role": "user", "content": addition})
    return messages


def _response_text(response: dict[str, Any]) -> str:
    try:
        return _content_text(response["choices"][0]["message"]["content"])
    except (KeyError, IndexError, TypeError):
        return ""


def _router_decision(text: str, has_images: bool, threshold: float) -> str:
    candidate = text.strip()
    if candidate.startswith("```"):
        candidate = re.sub(r"^```(?:json)?\s*|\s*```$", "", candidate, flags=re.I)
    try:
        decision = json.loads(candidate)
    except json.JSONDecodeError:
        start, end = candidate.find("{"), candidate.rfind("}")
        if start < 0 or end <= start:
            raise ValueError("router returned invalid JSON")
        decision = json.loads(candidate[start : end + 1])
    route = decision.get("route") if isinstance(decision, dict) else None
    confidence = decision.get("confidence") if isinstance(decision, dict) else None
    reason = decision.get("reason") if isinstance(decision, dict) else None
    if (
        route not in VALID_ROUTES
        or isinstance(confidence, bool)
        or not isinstance(confidence, (int, float))
        or not isinstance(reason, str)
        or not reason.strip()
    ):
        raise ValueError("router returned an invalid decision")
    if not 0 <= float(confidence) <= 1 or float(confidence) < threshold:
        raise ValueError("router confidence is insufficient")
    if re.search(r"\b(uncertain|unsure|unknown|niepewn\w*|nie wiadomo)\b", reason, re.I):
        raise ValueError("router explicitly reported uncertainty")
    if has_images and route == "reasoning":
        return "vision_reasoning"
    if has_images and route == "coder":
        return "vision_coder"
    if not has_images and route.startswith("vision_"):
        return route.removeprefix("vision_")
    return route


class AutoOrchestrator:
    def __init__(
        self, settings: Settings, transport: httpx.AsyncBaseTransport | None = None
    ) -> None:
        self.settings = settings
        self.transport = transport
        internal_models = {
            settings.router_model,
            settings.vision_model,
            settings.reasoning_model,
            settings.coder_model,
        }
        if "auto" in internal_models:
            raise ValueError("internal AUTO routes must never target model 'auto'")

    def _headers(self) -> dict[str, str]:
        return {
            "Authorization": f"Bearer {self.settings.litellm_api_key}",
            "Content-Type": "application/json",
        }

    async def _complete(
        self, model: str, messages: list[dict[str, Any]], timeout: float
    ) -> dict[str, Any]:
        payload = {"model": model, "messages": messages, "stream": False}
        if model == self.settings.router_model:
            payload.update({"temperature": 0, "max_tokens": 192})
        elif model == self.settings.vision_model:
            payload.update({"temperature": 0.1, "max_tokens": 1200})
        async with httpx.AsyncClient(
            transport=self.transport, timeout=httpx.Timeout(timeout)
        ) as client:
            response = await client.post(
                f"{self.settings.litellm_base_url}/chat/completions",
                headers=self._headers(),
                json=payload,
            )
            response.raise_for_status()
            return response.json()

    async def prepare(self, request_payload: dict[str, Any]) -> PreparedRequest:
        messages = request_payload.get("messages")
        if not isinstance(messages, list) or not all(
            isinstance(message, dict) for message in messages
        ):
            raise ValueError("messages must be an array of objects")

        images = collect_images(messages)
        image_count = len(images)
        vision_ms = 0
        fallback = False
        vision_report: str | None = None

        if images:
            started = time.monotonic()
            vision_messages = [
                {"role": "system", "content": VISION_PROMPT},
                {
                    "role": "user",
                    "content": [
                        {
                            "type": "text",
                            "text": latest_user_text(messages)
                            or "Analyze all attached images.",
                        },
                        *images,
                    ],
                },
            ]
            try:
                result = await self._complete(
                    self.settings.vision_model,
                    vision_messages,
                    self.settings.vision_timeout,
                )
                vision_report = _response_text(result).strip()
                if not vision_report:
                    raise ValueError("vision returned an empty report")
            except (httpx.HTTPError, ValueError, KeyError, TypeError) as error:
                LOGGER.warning("vision worker failed: %s", type(error).__name__)
                fallback = True
                vision_report = (
                    "Vision worker failed; attached image could not be analyzed. "
                    "Do not infer or invent its contents."
                )
            vision_ms = round((time.monotonic() - started) * 1000)

        router_started = time.monotonic()
        try:
            router_result = await self._complete(
                self.settings.router_model,
                [
                    {"role": "system", "content": ROUTER_PROMPT},
                    {
                        "role": "user",
                        "content": json.dumps(
                            {
                                "has_images": bool(images),
                                "request": latest_user_text(messages),
                            },
                            ensure_ascii=False,
                        ),
                    },
                ],
                self.settings.router_timeout,
            )
            route = _router_decision(
                _response_text(router_result),
                bool(images),
                self.settings.router_confidence,
            )
        except (httpx.HTTPError, ValueError, KeyError, TypeError) as error:
            LOGGER.warning("router fallback: %s", type(error).__name__)
            route = "vision_reasoning" if images else "reasoning"
            fallback = True
        router_ms = round((time.monotonic() - router_started) * 1000)

        final_messages = copy.deepcopy(messages)
        if images:
            final_messages = strip_images_from_messages(final_messages)
            final_messages = append_vision_report(final_messages, vision_report or "")

        target_model = (
            self.settings.coder_model
            if route in {"coder", "vision_coder"}
            else self.settings.reasoning_model
        )
        final_payload = copy.deepcopy(request_payload)
        final_payload["model"] = target_model
        final_payload["messages"] = final_messages
        return PreparedRequest(
            payload=final_payload,
            target_model=target_model,
            route=route,
            image_count=image_count,
            router_ms=router_ms,
            vision_ms=vision_ms,
            fallback=fallback,
        )

    async def send_final(
        self, prepared: PreparedRequest, request_id: str
    ) -> Response:
        started = time.monotonic()
        payload = prepared.payload
        stream = payload.get("stream") is True
        target = prepared.target_model

        async def open_response(model: str) -> tuple[httpx.AsyncClient, httpx.Response]:
            forwarded = copy.deepcopy(payload)
            forwarded["model"] = model
            client = httpx.AsyncClient(
                transport=self.transport,
                timeout=httpx.Timeout(self.settings.final_timeout),
            )
            upstream_request = client.build_request(
                "POST",
                f"{self.settings.litellm_base_url}/chat/completions",
                headers=self._headers(),
                json=forwarded,
            )
            try:
                response = await client.send(upstream_request, stream=stream)
            except Exception:
                await client.aclose()
                raise
            return client, response

        try:
            client, upstream = await open_response(target)
            if upstream.status_code >= 400 and target == self.settings.coder_model:
                LOGGER.warning(
                    "request=%s coder_status=%d fallback=reasoning",
                    request_id,
                    upstream.status_code,
                )
                await upstream.aread()
                await upstream.aclose()
                await client.aclose()
                prepared.fallback = True
                target = self.settings.reasoning_model
                prepared.route = "reasoning"
                client, upstream = await open_response(target)
        except httpx.HTTPError as error:
            if target == self.settings.coder_model:
                prepared.fallback = True
                target = self.settings.reasoning_model
                prepared.route = "reasoning"
                try:
                    client, upstream = await open_response(target)
                except httpx.HTTPError as fallback_error:
                    return _upstream_error(request_id, fallback_error)
            else:
                return _upstream_error(request_id, error)

        if upstream.status_code >= 400:
            LOGGER.error(
                "request=%s backend=%s status=%d",
                request_id,
                target,
                upstream.status_code,
            )

        response_headers = {
            "X-Request-ID": request_id,
            "X-Auto-Route": prepared.route,
        }

        if not stream:
            content = await upstream.aread()
            status_code = upstream.status_code
            media_type = upstream.headers.get("content-type", "application/json")
            await upstream.aclose()
            await client.aclose()
            self._log_summary(
                request_id, prepared, round((time.monotonic() - started) * 1000)
            )
            return Response(
                content=content,
                status_code=status_code,
                media_type=media_type.split(";", 1)[0],
                headers=response_headers,
            )

        async def body() -> AsyncIterator[bytes]:
            try:
                async for chunk in upstream.aiter_raw():
                    yield chunk
            finally:
                await upstream.aclose()
                await client.aclose()
                self._log_summary(
                    request_id,
                    prepared,
                    round((time.monotonic() - started) * 1000),
                )

        return StreamingResponse(
            body(),
            status_code=upstream.status_code,
            media_type=upstream.headers.get("content-type", "text/event-stream").split(
                ";", 1
            )[0],
            headers=response_headers,
        )

    @staticmethod
    def _log_summary(
        request_id: str, prepared: PreparedRequest, final_ms: int
    ) -> None:
        LOGGER.info(
            "request=%s images=%d route=%s router_ms=%d vision_ms=%d "
            "final_ms=%d fallback=%s",
            request_id,
            prepared.image_count,
            prepared.route,
            prepared.router_ms,
            prepared.vision_ms,
            final_ms,
            str(prepared.fallback).lower(),
        )


def _upstream_error(request_id: str, error: Exception) -> JSONResponse:
    LOGGER.error("request=%s backend_error=%s", request_id, type(error).__name__)
    return JSONResponse(
        status_code=502,
        content={
            "error": {
                "message": "AUTO could not reach the final model backend.",
                "type": "upstream_error",
            }
        },
        headers={"X-Request-ID": request_id},
    )


def create_app(
    settings: Settings | None = None,
    transport: httpx.AsyncBaseTransport | None = None,
) -> FastAPI:
    resolved = settings or Settings.from_environment()
    orchestrator = AutoOrchestrator(resolved, transport=transport)
    application = FastAPI(title="AUTO AI Router", version="1.0.0")

    @application.get("/health")
    async def health() -> dict[str, Any]:
        return {
            "status": "ok",
            "service": "auto-ai-router",
            "upstream": resolved.litellm_base_url,
        }

    @application.get("/v1/models")
    async def models() -> dict[str, Any]:
        return {
            "object": "list",
            "data": [
                {
                    "id": "auto",
                    "object": "model",
                    "owned_by": "auto-ai-router",
                }
            ],
        }

    @application.post("/v1/chat/completions")
    async def chat_completions(request: Request) -> Response:
        request_id = _request_id(request.headers.get("x-request-id"))
        try:
            payload = await request.json()
            if not isinstance(payload, dict):
                raise ValueError("request body must be an object")
            prepared = await orchestrator.prepare(payload)
        except (json.JSONDecodeError, ValueError) as error:
            return JSONResponse(
                status_code=400,
                content={
                    "error": {
                        "message": str(error),
                        "type": "invalid_request_error",
                    }
                },
                headers={"X-Request-ID": request_id},
            )
        return await orchestrator.send_final(prepared, request_id)

    application.state.orchestrator = orchestrator
    return application


app = create_app()
