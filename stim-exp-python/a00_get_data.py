#!/usr/bin/env python
"""Preprocess an experiment FIP session and save tables for Python analyses."""

from __future__ import annotations

import argparse
import json
import os
from pathlib import Path
import re
from typing import Any

_tmp_dir = Path(os.environ.get("TMPDIR", "/tmp"))
os.environ.setdefault("MPLCONFIGDIR", str(_tmp_dir / "matplotlib"))
os.environ.setdefault("XDG_CACHE_HOME", str(_tmp_dir / "cache"))

import matplotlib.pyplot as plt
import numpy as np
import pandas as pd
from scipy.interpolate import interp1d
from scipy.optimize import curve_fit

try:
    from fipster_io import load_raw_fip
except ImportError:  # pragma: no cover - supports package-style import
    from .fipster_io import load_raw_fip


#--------------------------------------------------------------------------
# Parameters
#--------------------------------------------------------------------------
# Edit these values and run the whole file, the same way as the MATLAB script.
input_mat_file = (
    "/Users/stefan/UCDrive/A SR/experiments/data/stefan0424/"
    "Z268_2_NAcMed-D1-MSN-axon-activation_10mW_7-pattern_n10_04242026.mat"
)

# Folder that contains the matching Fluorescence.csv / Events.csv export folder.
# Leave as None to use the folder containing input_mat_file.
csv_export_parent_folder = "/Users/stefan/UCDrive/A SR/experiments/data/stefan0424"

# Does the main .mat recording already contain both NAcMed and NAcLat?
# True: use two signal/reference pairs from the .mat file.
# False: the main .mat has one signal/reference pair; optionally add CSV below.
mat_file_has_two_regions = False

# Region identity of each .mat signal/reference pair, in raw channel order.
# The .mat file always has NAcLat; some .mat files also contain NAcMed.
mat_region_order = ("NAcLat", "NAcMed")

# If mat_file_has_two_regions is False, add Fluorescence.csv / Events.csv.
# The CSV export contains NAcMed.
add_csv_as_second_region = True
csv_region = "NAcMed"

# Save processed data here. Leave as None for ./processed next to this script.
processed_output_folder = None

# Show the overview diagnostic plot after saving.
show_overview_plot = False


DAY_MAP = {
    "04092026": 1,
    "04102026": 2,
    "04172026": 3,
    "04212026": 4,
    "04242026": 5,
}

ANIMAL_MAP = {
    "Z267_1": 1,
    "Z267_3": 2,
    "Z267_7": 3,
    "Z268_2": 4,
    "Z268_4": 5,
}

LAT_COLOR = "#1171BE"
MED_COLOR = "#DD5400"


def main() -> None:
    config = get_run_config()
    filename_path = Path(config["input_mat_file"]).expanduser()
    experiment_dir_path = (
        Path(config["csv_export_parent_folder"]).expanduser()
        if config["csv_export_parent_folder"] is not None
        else filename_path.parent
    )
    out_dir_path = (
        Path(config["processed_output_folder"]).expanduser()
        if config["processed_output_folder"] is not None
        else Path(__file__).resolve().parent / "processed"
    )
    filename_base = filename_path.stem
    filename2 = resolve_csv_folder(experiment_dir_path, filename_base, config["add_csv_as_second_region"])

    metadata = parse_metadata(filename_path)
    plot_title = build_metadata_title(metadata)

    raw = load_raw_fip(filename_path)
    n_signal_pairs = min(len(raw.sig), len(raw.ref))
    if n_signal_pairs < 1:
        raise ValueError(f"No signal/reference pairs found in {filename_path}.")
    if config["mat_file_has_two_regions"] and n_signal_pairs < 2:
        raise ValueError(
            f"mat_file_has_two_regions is True, but {filename_path} only contains "
            f"{n_signal_pairs} signal/reference pair(s)."
        )

    mat_file_has_two_regions_config = bool(config["mat_file_has_two_regions"])
    load_unaligned_csv_signal = bool(
        config["add_csv_as_second_region"] and not mat_file_has_two_regions_config
    )
    has_aligned_csv_second_signal = False
    single_signal_region = "NAcLat"
    csv_time_alignment: dict[str, Any] = {}

    time = np.asarray(raw.time, dtype=float)
    region_data = empty_region_data(time)
    n_mat_regions = 2 if mat_file_has_two_regions_config else 1
    mat_regions = tuple(normalize_region_name(r) for r in config["mat_region_order"])
    if len(mat_regions) < n_mat_regions:
        raise ValueError("mat_region_order must name every .mat signal/reference pair used.")

    for channel_idx in range(n_mat_regions):
        region = mat_regions[channel_idx]
        if region not in region_data:
            raise ValueError(f"Unsupported region in mat_region_order: {region}")
        channel_sig = np.asarray(raw.sig[channel_idx], dtype=float)
        channel_ref = np.asarray(raw.ref[channel_idx], dtype=float)
        channel_exp_curve = fit_exp2_curve(time, channel_sig)
        channel_zsc = zscore_after(channel_sig - channel_exp_curve, time, skip_s=0.5)
        region_data[region] = {
            "sig": channel_sig,
            "ref": channel_ref,
            "exp_curve": channel_exp_curve,
            "zsc": channel_zsc,
            "source": f"mat_channel_{channel_idx + 1}",
        }

    exp_curve = region_data["NAcMed"]["exp_curve"]
    exp_curve2 = region_data["NAcLat"]["exp_curve"]

    if raw.logai is None or raw.logai.shape[1] < 2:
        raise ValueError(f"No usable logAI TTL channel found for {filename_path}.")
    ttl = interpolate_nearest(
        raw.logai.iloc[:, 0].to_numpy(dtype=float),
        raw.logai.iloc[:, 1].to_numpy(dtype=float),
        time,
        fill_value=0.0,
    )

    T = pd.DataFrame(
        {
            "time": time,
            "sig": region_data["NAcMed"]["sig"],
            "ref": region_data["NAcMed"]["ref"],
            "sig2": region_data["NAcLat"]["sig"],
            "ref2": region_data["NAcLat"]["ref"],
            "ttl": ttl,
            "zsc_exp": region_data["NAcMed"]["zsc"],
            "zsc_exp2": region_data["NAcLat"]["zsc"],
        }
    )

    T_csv = pd.DataFrame()
    T_events_csv = pd.DataFrame()
    if config["add_csv_as_second_region"] and mat_file_has_two_regions_config:
        print("Skipping CSV second-region loading because mat_file_has_two_regions is True.")

    if load_unaligned_csv_signal:
        T_csv, T_events_csv = load_unaligned_csv_signal_tables(filename2)

    T_events, main_diag = detect_ttl_events(T["time"].to_numpy(), T["ttl"].to_numpy())
    print(f"Found {len(T_events)} valid TTL pulses")
    print(f"Threshold: {main_diag['threshold']:.3f}")
    print_ttl_counts(T_events, "TTL types")

    csv_alignment_error_times: np.ndarray = np.array([])
    csv_alignment_error_ms: np.ndarray = np.array([])
    if load_unaligned_csv_signal:
        if len(T_events) < 2:
            raise ValueError(f"Need at least 2 main TTL onsets to align CSV signal from {filename2}.")
        if len(T_events_csv) < 2:
            raise ValueError(f"Need at least 2 CSV TTL onsets to align CSV signal from {filename2}.")

        main_anchor_times = np.array([T_events["time"].iloc[0], T_events["time"].iloc[-1]])
        csv_anchor_times = np.array([T_events_csv["time"].iloc[0], T_events_csv["time"].iloc[-1]])
        csv_time_slope = np.diff(main_anchor_times)[0] / np.diff(csv_anchor_times)[0]
        csv_time_intercept = main_anchor_times[0] - csv_time_slope * csv_anchor_times[0]

        T_csv["time_aligned"] = csv_time_slope * T_csv["time"] + csv_time_intercept
        T_events_csv["time_aligned"] = csv_time_slope * T_events_csv["time"] + csv_time_intercept

        n_paired = min(len(T_events), len(T_events_csv))
        if len(T_events) != len(T_events_csv):
            print(
                f"Warning: main TTL count ({len(T_events)}) differs from CSV TTL count "
                f"({len(T_events_csv)}); using first {n_paired} paired TTLs for diagnostics."
            )

        csv_alignment_error_times = T_events["time"].iloc[:n_paired].to_numpy()
        csv_alignment_error_s = (
            T_events_csv["time_aligned"].iloc[:n_paired].to_numpy()
            - T_events["time"].iloc[:n_paired].to_numpy()
        )
        csv_alignment_error_ms = csv_alignment_error_s * 1000
        T_events_csv["time_error_s"] = np.nan
        T_events_csv["time_error_ms"] = np.nan
        T_events_csv.loc[T_events_csv.index[:n_paired], "time_error_s"] = csv_alignment_error_s
        T_events_csv.loc[T_events_csv.index[:n_paired], "time_error_ms"] = csv_alignment_error_ms

        csv_region_name = normalize_region_name(config["csv_region"])
        if csv_region_name == "NAcMed":
            T["sig"] = interp_linear_nan(T_csv["time_aligned"], T_csv["sig"], T["time"])
            T["ref"] = interp_linear_nan(T_csv["time_aligned"], T_csv["ref"], T["time"])
            T["zsc_exp"] = interp_linear_nan(T_csv["time_aligned"], T_csv["zsc_exp"], T["time"])
            exp_curve = interp_linear_nan(T_csv["time_aligned"], T_csv["exp_curve"], T["time"])
            region_data["NAcMed"]["source"] = "csv"
        elif csv_region_name == "NAcLat":
            T["sig2"] = interp_linear_nan(T_csv["time_aligned"], T_csv["sig"], T["time"])
            T["ref2"] = interp_linear_nan(T_csv["time_aligned"], T_csv["ref"], T["time"])
            T["zsc_exp2"] = interp_linear_nan(T_csv["time_aligned"], T_csv["zsc_exp"], T["time"])
            exp_curve2 = interp_linear_nan(T_csv["time_aligned"], T_csv["exp_curve"], T["time"])
            region_data["NAcLat"]["source"] = "csv"
        else:
            raise ValueError(f"Unsupported csv_region: {config['csv_region']}")
        has_aligned_csv_second_signal = True
        has_second_signal = has_valid_trace(T["zsc_exp"]) and has_valid_trace(T["zsc_exp2"])

        csv_time_alignment = {
            "slope": float(csv_time_slope),
            "intercept": float(csv_time_intercept),
            "main_anchor_times": main_anchor_times.tolist(),
            "csv_anchor_times": csv_anchor_times.tolist(),
            "n_paired_ttls": int(n_paired),
            "error_times": csv_alignment_error_times.tolist(),
            "error_s": csv_alignment_error_s.tolist(),
            "error_ms": csv_alignment_error_ms.tolist(),
        }
        abs_error = np.abs(csv_alignment_error_ms[np.isfinite(csv_alignment_error_ms)])
        if len(abs_error):
            if csv_region_name == "NAcMed":
                csv_target = "T.sig/ref/zsc_exp"
            else:
                csv_target = "T.sig2/ref2/zsc_exp2"
            print(f"Aligned CSV signal from {filename2} into {csv_target}")
            print(
                "CSV TTL alignment error: "
                f"median {np.median(abs_error):.3f} ms, max abs {np.max(abs_error):.3f} ms"
            )

    has_second_signal = has_valid_trace(T["zsc_exp"]) and has_valid_trace(T["zsc_exp2"])

    session_out_dir = out_dir_path / filename_base
    session_out_dir.mkdir(parents=True, exist_ok=True)
    T.to_parquet(session_out_dir / "T.parquet", index=False)
    T_events.to_parquet(session_out_dir / "T_events.parquet", index=False)
    if load_unaligned_csv_signal:
        T_csv.to_parquet(session_out_dir / "T_csv.parquet", index=False)
        T_events_csv.to_parquet(session_out_dir / "T_events_csv.parquet", index=False)

    metadata.update(
        {
            "filename": str(filename_path),
            "filename_base": filename_base,
            "fip_loader_source": raw.source,
            "mat_file_has_two_regions": bool(config["mat_file_has_two_regions"]),
            "mat_region_order": list(mat_regions),
            "has_second_signal": bool(has_second_signal),
            "single_signal_region": single_signal_region,
            "add_csv_as_second_region": bool(config["add_csv_as_second_region"]),
            "csv_region": normalize_region_name(config["csv_region"]),
            "region_sources": {
                "NAcMed": region_data["NAcMed"]["source"],
                "NAcLat": region_data["NAcLat"]["source"],
            },
            "filename2": str(filename2),
            "has_unaligned_second_signal": bool(load_unaligned_csv_signal),
            "has_aligned_csv_second_signal": bool(has_aligned_csv_second_signal),
            "csv_time_alignment": csv_time_alignment,
            "processed_dir": str(session_out_dir),
        }
    )
    (session_out_dir / "metadata.json").write_text(json.dumps(metadata, indent=2), encoding="utf-8")

    print(
        f"Saved {metadata['animal']} - {metadata['day_label']} - {metadata['power']} "
        f"to {session_out_dir}"
    )

    if config["show_overview_plot"]:
        plot_overview(
            T,
            exp_curve,
            exp_curve2,
            has_second_signal,
            has_aligned_csv_second_signal,
            csv_alignment_error_times,
            csv_alignment_error_ms,
            single_signal_region,
            plot_title,
        )
        plt.show()


def get_run_config() -> dict[str, Any]:
    args = parse_args()
    return {
        "input_mat_file": args.input_mat_file if args.input_mat_file is not None else input_mat_file,
        "csv_export_parent_folder": args.csv_export_parent_folder
        if args.csv_export_parent_folder is not None
        else csv_export_parent_folder,
        "processed_output_folder": args.processed_output_folder
        if args.processed_output_folder is not None
        else processed_output_folder,
        "mat_file_has_two_regions": args.mat_file_has_two_regions
        if args.mat_file_has_two_regions is not None
        else mat_file_has_two_regions,
        "mat_region_order": tuple(args.mat_region_order)
        if args.mat_region_order is not None
        else tuple(mat_region_order),
        "add_csv_as_second_region": args.add_csv_as_second_region
        if args.add_csv_as_second_region is not None
        else add_csv_as_second_region,
        "csv_region": args.csv_region if args.csv_region is not None else csv_region,
        "show_overview_plot": args.show_overview_plot
        if args.show_overview_plot is not None
        else show_overview_plot,
    }


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--input-mat-file", "--filename", dest="input_mat_file", default=None)
    parser.add_argument(
        "--csv-export-parent-folder",
        "--experiment-dir",
        dest="csv_export_parent_folder",
        default=None,
    )
    parser.add_argument(
        "--processed-output-folder",
        "--out-dir",
        dest="processed_output_folder",
        default=None,
    )
    parser.add_argument(
        "--mat-file-has-two-regions",
        "--main-file-has-two-regions",
        "--two-signals",
        dest="mat_file_has_two_regions",
        action=argparse.BooleanOptionalAction,
        default=None,
    )
    parser.add_argument("--mat-region-order", nargs="+", default=None)
    parser.add_argument(
        "--add-csv-as-second-region",
        "--csv-second-signal",
        dest="add_csv_as_second_region",
        action=argparse.BooleanOptionalAction,
        default=None,
    )
    parser.add_argument("--csv-region", default=None)
    parser.add_argument(
        "--show-overview-plot",
        "--show-overview",
        dest="show_overview_plot",
        action=argparse.BooleanOptionalAction,
        default=None,
    )
    return parser.parse_args()


def parse_metadata(filename: Path) -> dict[str, str]:
    fname = filename.stem
    animal_match = re.search(r"^([A-Z0-9_]+\d+)_", fname)
    power_match = re.search(r"_(\d+(?:-\d+)?)mW_", fname)
    date_match = re.search(r"_(\d{8})$", fname)
    date_str = date_match.group(1) if date_match else ""
    power = f"{power_match.group(1).replace('-', '.')}mW" if power_match else ""
    raw_animal = animal_match.group(1) if animal_match else ""
    animal = map_or_keep(raw_animal, ANIMAL_MAP, "animal")
    day_index = map_day_index(date_str)
    return {
        "animal": animal,
        "raw_animal": raw_animal,
        "power": power,
        "date": date_str,
        "day_index": day_index,
        "day_label": day_label_from_index(day_index),
    }


def build_metadata_title(metadata: dict[str, Any]) -> str:
    mouse_name = metadata.get("raw_animal") or metadata.get("animal") or ""
    animal_number = metadata.get("animal", "")
    date = metadata.get("date", "")
    day_index = metadata.get("day_index", "")
    day_text = f"day {day_index}" if day_index not in ("", None) else ""
    power = metadata.get("power", "")
    parts = [
        f"mouse {mouse_name}" if mouse_name else "",
        f"animal {animal_number}" if animal_number not in ("", None) else "",
        f"date {date}" if date else "",
        day_text,
        power,
    ]
    return " - ".join(str(part) for part in parts if part)


def map_or_keep(value: str, mapping: dict[str, Any], label: str) -> Any:
    if not value:
        return ""
    if value in mapping:
        return mapping[value]
    print(f"Warning: {label} '{value}' is not in map; using raw value.")
    return value


def map_day_index(date_str: str) -> int | None:
    if not date_str:
        return None
    if date_str in DAY_MAP:
        return DAY_MAP[date_str]
    print(f"Warning: date '{date_str}' is not in DAY_MAP; day_index will be None.")
    return None


def day_label_from_index(day_index: int | None) -> str:
    if day_index is None:
        return "unmapped_day"
    return f"day{day_index}"


def empty_region_data(time: np.ndarray) -> dict[str, dict[str, Any]]:
    def empty_channel() -> dict[str, Any]:
        return {
            "sig": np.full_like(time, np.nan, dtype=float),
            "ref": np.full_like(time, np.nan, dtype=float),
            "exp_curve": np.full_like(time, np.nan, dtype=float),
            "zsc": np.full_like(time, np.nan, dtype=float),
            "source": None,
        }

    return {"NAcMed": empty_channel(), "NAcLat": empty_channel()}


def normalize_region_name(region: str) -> str:
    cleaned = str(region).strip().lower().replace("-", "").replace("_", "")
    aliases = {
        "nacmed": "NAcMed",
        "med": "NAcMed",
        "nacmedial": "NAcMed",
        "naclat": "NAcLat",
        "lat": "NAcLat",
        "naclateral": "NAcLat",
    }
    if cleaned not in aliases:
        raise ValueError(f"Unknown region name: {region}. Use NAcMed or NAcLat.")
    return aliases[cleaned]


def has_valid_trace(trace: pd.Series | np.ndarray) -> bool:
    values = np.asarray(trace, dtype=float)
    return bool(np.any(np.isfinite(values)))


def resolve_csv_folder(experiment_dir: Path, filename_base: str, enabled: bool) -> Path:
    filename2 = experiment_dir / filename_base
    if enabled and not filename2.is_dir():
        matches = [p for p in experiment_dir.glob(f"*{filename_base}") if p.is_dir()]
        if not matches:
            raise FileNotFoundError(f"Could not find experiment folder matching {filename_base} in {experiment_dir}.")
        filename2 = matches[0]
    return filename2


def exp2_model(x: np.ndarray, a: float, b: float, c: float, d: float) -> np.ndarray:
    bx = np.clip(b * x, -700, 700)
    dx = np.clip(d * x, -700, 700)
    return a * np.exp(bx) + c * np.exp(dx)


def fit_exp2_curve(time: np.ndarray, signal: np.ndarray) -> np.ndarray:
    time = np.asarray(time, dtype=float)
    signal = np.asarray(signal, dtype=float)
    finite = np.isfinite(time) & np.isfinite(signal)
    if finite.sum() < 6:
        return np.full_like(signal, np.nan, dtype=float)

    x = time[finite] - time[finite][0]
    y = signal[finite]
    span = max(float(x[-1] - x[0]), 1.0)
    y0 = float(y[0])
    y_end = float(np.median(y[-max(3, len(y) // 20) :]))
    amp = y0 - y_end
    p0 = [amp * 0.7 if amp else y0 * 0.1, -1.0 / span, amp * 0.3 if amp else y0 * 0.01, -0.01 / span]

    try:
        popt, _ = curve_fit(exp2_model, x, y, p0=p0, maxfev=20000)
        fitted = np.full_like(signal, np.nan, dtype=float)
        fitted[finite] = exp2_model(x, *popt)
        if finite.sum() != len(signal):
            interp = interp1d(time[finite], fitted[finite], bounds_error=False, fill_value="extrapolate")
            fitted = np.asarray(interp(time), dtype=float)
        return fitted
    except Exception as exc:
        print(f"Warning: exp2 fit failed ({exc}); using a linear baseline fallback.")
        coef = np.polyfit(x, y, 1)
        fitted = np.full_like(signal, np.nan, dtype=float)
        fitted[finite] = np.polyval(coef, x)
        return fitted


def zscore_after(values: np.ndarray, time: np.ndarray, skip_s: float) -> np.ndarray:
    start = np.argmax(time >= skip_s) if np.any(time >= skip_s) else 0
    baseline = np.asarray(values[start:], dtype=float)
    finite = baseline[np.isfinite(baseline)]
    if len(finite) < 2:
        return np.full_like(values, np.nan, dtype=float)
    mu = np.mean(finite)
    sd = np.std(finite, ddof=1)
    if sd == 0 or not np.isfinite(sd):
        return np.full_like(values, np.nan, dtype=float)
    return (values - mu) / sd


def interpolate_nearest(x: np.ndarray, y: np.ndarray, x_new: np.ndarray, fill_value: float) -> np.ndarray:
    interp = interp1d(x, y, kind="nearest", bounds_error=False, fill_value=fill_value)
    return np.asarray(interp(x_new), dtype=float)


def interp_linear_nan(x: pd.Series, y: pd.Series, x_new: pd.Series) -> np.ndarray:
    x_arr = x.to_numpy(dtype=float)
    y_arr = y.to_numpy(dtype=float)
    x_new_arr = x_new.to_numpy(dtype=float)
    finite = np.isfinite(x_arr) & np.isfinite(y_arr)
    out = np.full_like(x_new_arr, np.nan, dtype=float)
    if finite.sum() < 2:
        return out
    order = np.argsort(x_arr[finite])
    x_valid = x_arr[finite][order]
    y_valid = y_arr[finite][order]
    in_range = (x_new_arr >= x_valid[0]) & (x_new_arr <= x_valid[-1])
    out[in_range] = np.interp(x_new_arr[in_range], x_valid, y_valid)
    return out


def load_unaligned_csv_signal_tables(filename2: Path) -> tuple[pd.DataFrame, pd.DataFrame]:
    fluorescence_file = filename2 / "Fluorescence.csv"
    events_file = filename2 / "Events.csv"
    if not fluorescence_file.is_file():
        raise FileNotFoundError(f"Missing Fluorescence.csv in {filename2}.")
    if not events_file.is_file():
        raise FileNotFoundError(f"Missing Events.csv in {filename2}.")

    fluorescence = pd.read_csv(fluorescence_file, skiprows=1)
    required_fluorescence_cols = {"TimeStamp", "CH1-410", "CH1-470"}
    missing = required_fluorescence_cols.difference(fluorescence.columns)
    if missing:
        raise ValueError(f"Fluorescence.csv is missing column(s): {', '.join(sorted(missing))}.")

    fluorescence_time_ms = fluorescence["TimeStamp"].to_numpy(dtype=float)
    csv_time_origin_ms = fluorescence_time_ms[0]
    time_csv = (fluorescence_time_ms - csv_time_origin_ms) / 1000
    sig_csv = fluorescence["CH1-470"].to_numpy(dtype=float)
    ref_csv = fluorescence["CH1-410"].to_numpy(dtype=float)
    exp_curve_csv = fit_exp2_curve(time_csv, sig_csv)
    sig_cor_csv = sig_csv - exp_curve_csv
    zsc_exp_csv = zscore_after(sig_cor_csv, time_csv, skip_s=0.5)

    events = pd.read_csv(events_file)
    required_event_cols = {"TimeStamp", "State"}
    missing_events = required_event_cols.difference(events.columns)
    if missing_events:
        raise ValueError(f"Events.csv is missing column(s): {', '.join(sorted(missing_events))}.")

    event_time_csv = (events["TimeStamp"].to_numpy(dtype=float) - csv_time_origin_ms) / 1000
    event_state_csv = events["State"].to_numpy(dtype=int)
    ttl_csv = np.zeros_like(time_csv, dtype=float)
    csv_onset_times: list[float] = []
    csv_offset_times: list[float] = []
    active_onset: float | None = None

    for this_time, this_state in zip(event_time_csv, event_state_csv):
        if this_state == 0:
            ttl_csv[time_csv >= this_time] = 1
            active_onset = float(this_time)
        elif this_state == 1:
            ttl_csv[time_csv >= this_time] = 0
            if active_onset is not None:
                csv_onset_times.append(active_onset)
                csv_offset_times.append(float(this_time))
                active_onset = None

    T_events_csv = classify_ttl_pulses(np.array(csv_onset_times), np.array(csv_offset_times))
    T_csv = pd.DataFrame(
        {
            "time": time_csv,
            "sig": sig_csv,
            "ref": ref_csv,
            "ttl": ttl_csv,
            "exp_curve": exp_curve_csv,
            "sig_cor": sig_cor_csv,
            "zsc_exp": zsc_exp_csv,
        }
    )

    print(f"Loaded unaligned CSV signal from {filename2}")
    print(f"Found {len(T_events_csv)} valid CSV TTL pulses")
    print_ttl_counts(T_events_csv, "CSV TTL types")
    return T_csv, T_events_csv


def detect_ttl_events(ttl_time: np.ndarray, ttl: np.ndarray) -> tuple[pd.DataFrame, dict[str, float]]:
    threshold = float(np.mean([np.nanpercentile(ttl, 10), np.nanpercentile(ttl, 99)]))
    above = (ttl > threshold).astype(int)
    rising = np.diff(np.r_[0, above]) == 1
    falling = np.diff(np.r_[above, 0]) == -1
    onset_idx = np.flatnonzero(rising)
    offset_idx = np.flatnonzero(falling)

    valid_onsets: list[float] = []
    valid_offsets: list[float] = []
    for idx in onset_idx:
        later_offsets = offset_idx[offset_idx > idx]
        if len(later_offsets) == 0:
            continue
        off_t = float(ttl_time[later_offsets[0]])
        on_t = float(ttl_time[idx])
        if off_t - on_t >= 0.2:
            valid_onsets.append(on_t)
            valid_offsets.append(off_t)

    return classify_ttl_pulses(np.array(valid_onsets), np.array(valid_offsets)), {"threshold": threshold}


def classify_ttl_pulses(onset_times: np.ndarray, offset_times: np.ndarray) -> pd.DataFrame:
    durations = offset_times - onset_times
    valid = durations >= 0.2
    onset_times = onset_times[valid]
    durations = durations[valid]
    expected = np.arange(1, 8, dtype=float) * 0.42
    ttl_type = np.array([int(np.argmin(np.abs(expected - d)) + 1) for d in durations], dtype=int)
    return pd.DataFrame({"type": ttl_type, "time": onset_times})


def print_ttl_counts(events: pd.DataFrame, title: str) -> None:
    print(f"\n{title}:")
    for ttl_type in range(1, 8):
        n_events = int((events["type"] == ttl_type).sum()) if not events.empty else 0
        print(f"  Type {ttl_type} ({ttl_type * 0.42:.2f}s): {n_events} pulses")


def plot_overview(
    T: pd.DataFrame,
    exp_curve: np.ndarray,
    exp_curve2: np.ndarray,
    has_second_signal: bool,
    has_aligned_csv_second_signal: bool,
    csv_alignment_error_times: np.ndarray,
    csv_alignment_error_ms: np.ndarray,
    single_signal_region: str,
    plot_title: str,
) -> None:
    rows = 3 + 3 * int(has_second_signal) + int(has_aligned_csv_second_signal)
    fig, axes = plt.subplots(rows, 1, figsize=(16, max(6, rows * 1.8)), sharex=True, constrained_layout=True)
    axes = np.atleast_1d(axes)
    row = 0
    time = T["time"].to_numpy()
    ttl = T["ttl"].to_numpy()

    if has_aligned_csv_second_signal:
        axes[row].scatter(csv_alignment_error_times, csv_alignment_error_ms, s=18, color=LAT_COLOR)
        axes[row].axhline(0, color="k", lw=0.8)
        axes[row].set_ylabel("CSV TTL error (ms)")
        row += 1

    if has_second_signal:
        primary_raw = T["sig"].to_numpy()
        primary_ref = T["ref"].to_numpy()
        primary_fit = exp_curve
        primary_zsc = T["zsc_exp"].to_numpy()
        primary_color = MED_COLOR
        primary_label = "NAcMed"
    else:
        primary_raw = T["sig2"].to_numpy()
        primary_ref = T["ref2"].to_numpy()
        primary_fit = exp_curve2
        primary_zsc = T["zsc_exp2"].to_numpy()
        primary_color = LAT_COLOR
        primary_label = single_signal_region

    axes[row].plot(time, primary_raw, color=primary_color, lw=0.8)
    axes[row].plot(time, primary_fit, color="r", lw=1.2)
    axes[row].set_ylabel(f"Raw {primary_label}")
    row += 1

    if has_second_signal:
        axes[row].plot(time, T["sig2"], color=LAT_COLOR, lw=0.8)
        axes[row].plot(time, exp_curve2, color="r", lw=1.2)
        axes[row].set_ylabel("Raw NAcLat")
        row += 1

    axes[row].plot(time, primary_zsc, color=primary_color, lw=0.8)
    axes[row].set_ylabel(f"Z-score {primary_label}")
    row += 1

    if has_second_signal:
        axes[row].plot(time, T["zsc_exp2"], color=LAT_COLOR, lw=0.8)
        axes[row].set_ylabel("Z-score NAcLat")
        row += 1

    plot_signal_ref_ttl_panel(
        axes[row],
        time,
        primary_zsc,
        primary_ref,
        ttl,
        primary_color,
        primary_label,
    )
    row += 1

    if has_second_signal:
        plot_signal_ref_ttl_panel(
            axes[row],
            time,
            T["zsc_exp2"].to_numpy(),
            T["ref2"].to_numpy(),
            ttl,
            LAT_COLOR,
            "NAcLat",
        )

    axes[-1].set_xlabel("Time (s)")
    fig.suptitle(plot_title)


def plot_signal_ref_ttl_panel(
    ax_signal: plt.Axes,
    time: np.ndarray,
    zsc_trace: np.ndarray,
    reference_trace: np.ndarray,
    ttl: np.ndarray,
    signal_color: str,
    signal_label: str,
) -> None:
    ax_ref = ax_signal.twinx()
    signal_line = ax_signal.plot(time, zsc_trace, color=signal_color, lw=0.8, label=signal_label)
    ref_line = ax_ref.plot(time, reference_trace, color="0.45", lw=0.6, label="Reference")
    ttl_line = ax_ref.plot(time, rescale(ttl, reference_trace), color="k", lw=0.4, label="TTL")

    ax_signal.set_ylabel(f"{signal_label} z-score", color=signal_color)
    ax_ref.set_ylabel("Reference / TTL", color="0.35")
    ax_signal.tick_params(axis="y", colors=signal_color)
    ax_ref.tick_params(axis="y", colors="0.35")
    ax_signal.spines["left"].set_color(signal_color)
    ax_ref.spines["right"].set_color("0.35")

    lines = signal_line + ref_line + ttl_line
    ax_signal.legend(lines, [line.get_label() for line in lines], loc="best", fontsize=8)


def rescale(values: np.ndarray, target: np.ndarray) -> np.ndarray:
    finite = target[np.isfinite(target)]
    if len(finite) == 0:
        return np.full_like(values, np.nan, dtype=float)
    out_min = float(np.min(finite))
    out_max = float(np.max(finite))
    v_min = float(np.nanmin(values))
    v_max = float(np.nanmax(values))
    if v_max == v_min:
        return np.full_like(values, out_min, dtype=float)
    return (values - v_min) / (v_max - v_min) * (out_max - out_min) + out_min


if __name__ == "__main__":
    main()
