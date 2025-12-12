#!/usr/bin/env python3
import argparse
import importlib
import os
import sys
from pathlib import Path
from cocotb.runner import get_runner

def main():
    parser = argparse.ArgumentParser(description="Generic Cocotb Test Runner")
    parser.add_argument("--test", "-t", nargs="+", help="Test modules to run (without .py)")
    parser.add_argument("--exclude", "-x", nargs="+", help="Test modules to exclude")
    parser.add_argument("--sim", default="icarus", help="Simulator: icarus, verilator, etc.")
    parser.add_argument("--waves", action="store_true", help="Enable waveform dumping")
    args = parser.parse_args()

    sim_dir = Path(__file__).resolve().parent
    project_root = sim_dir.parent
    tests_dir = sim_dir / "tests"
    sys.path.append(str(tests_dir))
    sys.path.append(str(project_root / "hdl"))

    all_tests = [
        f.stem for f in tests_dir.glob("test_*.py")
        if f.is_file() and not f.stem.startswith("__")
    ]

    selected = args.test or all_tests
    if args.exclude:
        selected = [t for t in selected if t not in args.exclude]

    print(f"Running tests: {selected}")

    for test_name in selected:
        mod = importlib.import_module(test_name)
        print(f"\nRunning {test_name}...")

        sources = getattr(mod, "SOURCES", [])
        hdl_toplevel = getattr(mod, "TOPLEVEL", None)
        params = getattr(mod, "PARAMS", {})
        build_args = getattr(mod, "BUILD_ARGS", ["-Wall"])
        timescale = getattr(mod, "TIMESCALE", ("1ns", "1ps"))
        test_module = test_name
        sim_args = getattr(mod, "SIM_ARGS", [])

        if not sources or not hdl_toplevel:
            print(f"{test_name} missing SOURCES or TOPLEVEL definition.")
            continue

        runner = get_runner(args.sim)
        runner.build(
            sources=sources,
            hdl_toplevel=hdl_toplevel,
            parameters=params,
            build_args=build_args,
            timescale=timescale,
            waves=args.waves,
            always=True
        )

        runner.test(
            hdl_toplevel=hdl_toplevel,
            test_module=test_module,
            test_args=sim_args,
            waves=args.waves
        )

if __name__ == "__main__":
    main()
