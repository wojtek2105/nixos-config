{ pkgs, ... }:

{
  # Opcjonalny harness jest instalowany wyłącznie po jawnym włączeniu
  # features.schedulerBenchmark. Nie uruchamia usługi ani timera; dodaje tylko
  # polecenie wraz ze stress-ng, SuperTuxKart i schedulerami SCX.
  environment.systemPackages = [
    (pkgs.callPackage ../tools/scheduler-benchmark { })
  ];
}
