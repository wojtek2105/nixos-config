import json

import httpx
import pytest

from auto_ai_router import AutoOrchestrator, Settings, collect_images


PNG = "iVBORw0KGgoAAAANSUhEUgAAAAEAAAAB"


def completion(content: str) -> dict:
    return {"choices": [{"message": {"role": "assistant", "content": content}}]}


class FakeOrchestrator(AutoOrchestrator):
    def __init__(self, responses: dict[str, object]):
        super().__init__(Settings())
        self.responses = responses
        self.calls: list[tuple[str, list[dict]]] = []

    async def _complete(self, model, messages, timeout):
        self.calls.append((model, messages))
        result = self.responses[model]
        if isinstance(result, Exception):
            raise result
        return completion(str(result))


def test_settings_use_litellm_master_key_for_internal_calls(monkeypatch):
    monkeypatch.delenv("AUTO_AI_LITELLM_API_KEY", raising=False)
    monkeypatch.setenv("LITELLM_MASTER_KEY", "sk-local-test")
    assert Settings.from_environment().litellm_api_key == "sk-local-test"


def test_explicit_auto_key_precedes_litellm_master_key(monkeypatch):
    monkeypatch.setenv("AUTO_AI_LITELLM_API_KEY", "explicit-auto-key")
    monkeypatch.setenv("LITELLM_MASTER_KEY", "sk-local-test")
    assert Settings.from_environment().litellm_api_key == "explicit-auto-key"


@pytest.mark.asyncio
async def test_a_text_question_routes_to_reasoning():
    router = FakeOrchestrator(
        {"router": '{"route":"reasoning","confidence":0.96,"reason":"general"}'}
    )
    prepared = await router.prepare(
        {"model": "auto", "messages": [{"role": "user", "content": "question"}]}
    )
    assert prepared.target_model == "reasoning"
    assert prepared.route == "reasoning"


@pytest.mark.asyncio
async def test_b_image_always_runs_vision_then_reasoning():
    router = FakeOrchestrator(
        {
            "vision": "VISIBLE ERROR: service failed",
            "router": '{"route":"reasoning","confidence":0.9,"reason":"debug"}',
        }
    )
    payload = {
        "model": "auto",
        "messages": [
            {
                "role": "user",
                "content": [
                    {"type": "text", "text": "diagnose"},
                    {
                        "type": "image_url",
                        "image_url": {"url": f"data:image/png;base64,{PNG}"},
                    },
                ],
            }
        ],
    }
    prepared = await router.prepare(payload)
    assert [call[0] for call in router.calls] == ["vision", "router"]
    assert prepared.route == "vision_reasoning"
    assert prepared.target_model == "reasoning"
    assert collect_images(prepared.payload["messages"]) == []
    assert "VISIBLE ERROR" in json.dumps(prepared.payload["messages"])


@pytest.mark.asyncio
async def test_c_invalid_router_json_falls_back_to_reasoning():
    router = FakeOrchestrator({"router": "not json"})
    prepared = await router.prepare(
        {"model": "auto", "messages": [{"role": "user", "content": "question"}]}
    )
    assert prepared.target_model == "reasoning"
    assert prepared.fallback is True


@pytest.mark.asyncio
async def test_d_router_timeout_falls_back_to_reasoning():
    router = FakeOrchestrator({"router": httpx.ReadTimeout("router timeout")})
    prepared = await router.prepare(
        {"model": "auto", "messages": [{"role": "user", "content": "question"}]}
    )
    assert prepared.target_model == "reasoning"
    assert prepared.fallback is True


@pytest.mark.asyncio
async def test_e_vision_failure_is_explicit_and_never_invents_content():
    router = FakeOrchestrator(
        {
            "vision": httpx.ReadTimeout("vision timeout"),
            "router": '{"route":"vision_reasoning","confidence":0.9,"reason":"image"}',
        }
    )
    payload = {
        "model": "auto",
        "messages": [
            {
                "role": "user",
                "content": [
                    {"type": "text", "text": "diagnose"},
                    {"type": "image_url", "image_url": f"data:image/png;base64,{PNG}"},
                ],
            }
        ],
    }
    prepared = await router.prepare(payload)
    serialized = json.dumps(prepared.payload["messages"])
    assert "Vision worker failed; attached image could not be analyzed." in serialized
    assert collect_images(prepared.payload["messages"]) == []


@pytest.mark.asyncio
async def test_f_tools_and_tool_choice_reach_the_final_worker_unchanged():
    router = FakeOrchestrator(
        {"router": '{"route":"coder","confidence":0.99,"reason":"repository"}'}
    )
    tools = [{"type": "function", "function": {"name": "read_file"}}]
    tool_choice = {"type": "function", "function": {"name": "read_file"}}
    messages = [
        {"role": "system", "content": "repository agent"},
        {"role": "user", "content": "edit code"},
        {
            "role": "assistant",
            "content": None,
            "tool_calls": [
                {
                    "id": "call-1",
                    "type": "function",
                    "function": {"name": "read_file", "arguments": "{}"},
                }
            ],
        },
        {"role": "tool", "tool_call_id": "call-1", "content": "file body"},
    ]
    prepared = await router.prepare(
        {
            "model": "auto",
            "messages": messages,
            "tools": tools,
            "tool_choice": tool_choice,
        }
    )
    assert prepared.target_model == "coder"
    assert prepared.payload["tools"] == tools
    assert prepared.payload["tool_choice"] == tool_choice
    assert prepared.payload["messages"] == messages
    router_input = json.dumps(router.calls[0][1])
    assert "read_file" not in router_input


@pytest.mark.asyncio
async def test_g_all_images_are_forwarded_to_vision():
    router = FakeOrchestrator(
        {
            "vision": "two image report",
            "router": '{"route":"vision_coder","confidence":0.9,"reason":"screenshots"}',
        }
    )
    payload = {
        "model": "auto",
        "messages": [
            {
                "role": "user",
                "content": [
                    {"type": "text", "text": "compare"},
                    {"type": "image_url", "image_url": f"data:image/png;base64,{PNG}"},
                    {"type": "input_image", "image_url": f"data:image/png;base64,{PNG}"},
                ],
            }
        ],
    }
    prepared = await router.prepare(payload)
    vision_call = router.calls[0]
    assert vision_call[0] == "vision"
    assert len(collect_images(vision_call[1])) == 2
    assert prepared.image_count == 2
    assert prepared.target_model == "coder"
