#!/usr/bin/env python
"""Plot session heatmaps and PSTHs from processed experiment FIP tables."""

from __future__ import annotations

import argparse
import json
import os
from pathlib import Path
from typing import Any

_tmp_dir = Path(os.environ.get("TMPDIR", "/tmp"))
os.environ.setdefault("MPLCONFIGDIR", str(_tmp_dir / "matplotlib"))
os.environ.setdefault("XDG_CACHE_HOME", str(_tmp_dir / "cache"))

import matplotlib.pyplot as plt
import numpy as np
import pandas as pd


LAT_COLOR = "#1171BE"
MED_COLOR = "#DD5400"
GUIDE_COLOR = "0.45"


def main() -> None:
    args = parse_args()
    sessions = load_processed_sessions(Path(args.processed_dir).expanduser())
    if not sessions:
        raise FileNotFoundError(f"No processed sessions found in {args.processed_dir}. Run a00_get_data.py first.")

    if args.view_mode == "single":
        data_entry = select_single_session(sessions, args.animal_index, args.day_index)
        sessions_to_plot = [data_entry]
        plot_title = f"{data_entry['metadata'].get('animal', '')} - {data_entry['metadata'].get('day_label', '')}"
    else:
        sessions_to_plot = [s for s in sessions if int(s["metadata"].get("day_index", 1)) == args.day_index]
        plot_title = f"Day {args.day_index} - {len(sessions_to_plot)} animals"

    if not sessions_to_plot:
        raise ValueError(f"No entries found for day {args.day_index}.")

    if args.view_mode == "single":
        has_second_signal = args.two_signals and has_two_signal_data(sessions_to_plot[0])
        if args.two_signals and not has_second_signal:
            animal = sessions_to_plot[0]["metadata"].get("animal", "")
            day = sessions_to_plot[0]["metadata"].get("day_label", "")
            raise ValueError(f"--two-signals was set, but {animal} {day} lacks a valid second signal.")
    else:
        has_second_signal = args.two_signals and any(has_two_signal_data(s) for s in sessions_to_plot)
        if args.two_signals and not has_second_signal:
            raise ValueError(f"--two-signals was set, but no valid second-signal data were found for day {args.day_index}.")

    first_time = sessions_to_plot[0]["T"]["time"].to_numpy(dtype=float)
    fs = 1.0 / np.median(np.diff(first_time))
    n_bl_start = int(round(abs(args.bl_start) * fs))
    n_post = int(round(args.post * fs))
    n_total_full = n_bl_start + n_post + 1
    t_axis_full = np.linspace(args.bl_start, args.post, n_total_full)
    bl_idx = (t_axis_full >= args.bl_start) & (t_axis_full <= args.bl_end)
    disp_idx = (t_axis_full >= -args.pre) & (t_axis_full <= args.post)
    t_axis = t_axis_full[disp_idx]

    stim_patterns = build_stim_patterns()
    n_rows = 5 if has_second_signal else 3
    fig, axes = plt.subplots(
        n_rows,
        len(stim_patterns),
        figsize=(len(stim_patterns) * 3.0, n_rows * 2.5),
        constrained_layout=True,
        squeeze=False,
    )
    fig.suptitle(plot_title, fontweight="bold")

    primary_color = MED_COLOR if has_second_signal else LAT_COLOR
    primary_label = "NAcMed" if has_second_signal else "NAcLat"
    psth_axes: list[plt.Axes] = []
    psth_axes_with_data: list[plt.Axes] = []

    for typ, pat in enumerate(stim_patterns, start=1):
        snippets, snippets2, animal_boundaries, animal_boundaries2, animal_means, animal_means2 = collect_snippets(
            sessions_to_plot,
            typ,
            args.view_mode,
            has_second_signal,
            n_bl_start,
            n_post,
            n_total_full,
            bl_idx,
            disp_idx,
        )

        ax0 = axes[0, typ - 1]
        plot_stimulus(ax0, pat, args.pre, args.post)

        ax1 = axes[1, typ - 1]
        plot_heatmap(ax1, snippets, t_axis, animal_boundaries)
        if typ == 1:
            ax1.set_ylabel(primary_label)
        ax1.tick_params(labelbottom=False)

        ax2 = axes[2, typ - 1]
        psth_axes.append(ax2)
        if plot_psth(ax2, t_axis, snippets, animal_means, args.view_mode, primary_color):
            psth_axes_with_data.append(ax2)
        if typ == 1:
            ax2.set_ylabel(primary_label)
        if has_second_signal:
            ax2.tick_params(labelbottom=False)
        else:
            ax2.set_xlabel("Time (s)")

        if has_second_signal:
            ax3 = axes[3, typ - 1]
            plot_heatmap(ax3, snippets2, t_axis, animal_boundaries2)
            if typ == 1:
                ax3.set_ylabel("NAcLat")
            ax3.tick_params(labelbottom=False)

            ax4 = axes[4, typ - 1]
            psth_axes.append(ax4)
            if plot_psth(ax4, t_axis, snippets2, animal_means2, args.view_mode, LAT_COLOR):
                psth_axes_with_data.append(ax4)
            ax4.set_xlabel("Time (s)")
            if typ == 1:
                ax4.set_ylabel("NAcLat")

    if has_second_signal and psth_axes_with_data:
        ylims = np.array([ax.get_ylim() for ax in psth_axes_with_data])
        common_ylim = [float(np.min(ylims[:, 0])), float(np.max(ylims[:, 1]))]
        if np.isfinite(common_ylim).all() and common_ylim[0] < common_ylim[1]:
            for ax in psth_axes:
                ax.set_ylim(common_ylim)

    add_psth_reference_lines(psth_axes_with_data, x_values=range(0, 4), y_values=range(-2, 3))

    if args.save:
        save_path = Path(args.save).expanduser()
        save_path.parent.mkdir(parents=True, exist_ok=True)
        fig.savefig(save_path, dpi=200)
        print(f"Saved figure to {save_path}")
    if not args.no_show:
        plt.show()
    else:
        plt.close(fig)


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--processed-dir", default=str(Path(__file__).resolve().parent / "processed"))
    parser.add_argument("--animal-index", type=int, default=1)
    parser.add_argument("--day-index", type=int, default=1)
    parser.add_argument("--view-mode", choices=["single", "across_animals"], default="single")
    parser.add_argument("--two-signals", action="store_true")
    parser.add_argument("--save", default=None)
    parser.add_argument("--no-show", action="store_true")
    parser.add_argument("--pre", type=float, default=2.0)
    parser.add_argument("--post", type=float, default=4.0)
    parser.add_argument("--bl-start", type=float, default=-7.0)
    parser.add_argument("--bl-end", type=float, default=-2.0)
    return parser.parse_args()


def load_processed_sessions(processed_dir: Path) -> list[dict[str, Any]]:
    sessions: list[dict[str, Any]] = []
    if not processed_dir.is_dir():
        return sessions
    for session_dir in sorted(p for p in processed_dir.iterdir() if p.is_dir()):
        metadata_file = session_dir / "metadata.json"
        t_file = session_dir / "T.parquet"
        events_file = session_dir / "T_events.parquet"
        if not (metadata_file.is_file() and t_file.is_file() and events_file.is_file()):
            continue
        metadata = json.loads(metadata_file.read_text(encoding="utf-8"))
        sessions.append(
            {
                "session_dir": session_dir,
                "metadata": metadata,
                "T": pd.read_parquet(t_file),
                "T_events": pd.read_parquet(events_file),
            }
        )
    return sorted(sessions, key=lambda s: (str(s["metadata"].get("animal", "")), int(s["metadata"].get("day_index", 1))))


def select_single_session(sessions: list[dict[str, Any]], animal_index: int, day_index: int) -> dict[str, Any]:
    animals = sorted({str(s["metadata"].get("animal", "")) for s in sessions})
    if animal_index < 1 or animal_index > len(animals):
        raise IndexError(f"animal-index {animal_index} is out of range for {len(animals)} animal(s).")
    animal = animals[animal_index - 1]
    matches = [
        s
        for s in sessions
        if str(s["metadata"].get("animal", "")) == animal and int(s["metadata"].get("day_index", 1)) == day_index
    ]
    if not matches:
        raise ValueError(f"No processed session found for animal-index {animal_index} ({animal}) day {day_index}.")
    return matches[0]


def build_stim_patterns() -> list[dict[str, Any]]:
    ramp_up = np.array(
        [0, 253, 475, 671, 844, 996, 1130, 1248, 1353, 1444, 1525, 1596, 1659, 1714, 1763, 1806, 1844, 1877, 1906, 1932, 1957],
        dtype=float,
    )
    ramp_down = ramp_up[-1] - np.flip(ramp_up)
    return [
        {"label": "1s 20Hz", "dur": 1.0, "freq": 20.0, "ramp": None},
        {"label": "2s 20Hz", "dur": 2.0, "freq": 20.0, "ramp": None},
        {"label": "Ramp up", "dur": 2.0, "freq": None, "ramp": ramp_up / 1000.0},
        {"label": "Ramp down", "dur": 2.0, "freq": None, "ramp": ramp_down / 1000.0},
        {"label": "3s 5Hz", "dur": 3.0, "freq": 5.0, "ramp": None},
        {"label": "3s 10Hz", "dur": 3.0, "freq": 10.0, "ramp": None},
        {"label": "3s 20Hz", "dur": 3.0, "freq": 20.0, "ramp": None},
    ]


def collect_snippets(
    sessions_to_plot: list[dict[str, Any]],
    typ: int,
    view_mode: str,
    has_second_signal: bool,
    n_bl_start: int,
    n_post: int,
    n_total_full: int,
    bl_idx: np.ndarray,
    disp_idx: np.ndarray,
) -> tuple[np.ndarray, np.ndarray, list[int], list[int], np.ndarray, np.ndarray]:
    if view_mode == "single":
        session = sessions_to_plot[0]
        event_times = session["T_events"].loc[session["T_events"]["type"] == typ, "time"].to_numpy(dtype=float)
        snippets, snippets2 = extract_snippets_single(
            session["T"], event_times, n_bl_start, n_post, n_total_full, bl_idx, disp_idx, has_second_signal
        )
        return snippets, snippets2, [], [], snippets, snippets2

    all_snippets: list[np.ndarray] = []
    all_snippets2: list[np.ndarray] = []
    animal_boundaries = [0]
    animal_boundaries2 = [0]
    animal_means: list[np.ndarray] = []
    animal_means2: list[np.ndarray] = []

    for session in sessions_to_plot:
        event_times = session["T_events"].loc[session["T_events"]["type"] == typ, "time"].to_numpy(dtype=float)
        snip, snip2 = extract_snippets_single(
            session["T"], event_times, n_bl_start, n_post, n_total_full, bl_idx, disp_idx, has_second_signal
        )
        if len(snip):
            all_snippets.append(snip)
            animal_boundaries.append(animal_boundaries[-1] + snip.shape[0])
            animal_means.append(np.nanmean(snip, axis=0))
        if has_second_signal and len(snip2):
            all_snippets2.append(snip2)
            animal_boundaries2.append(animal_boundaries2[-1] + snip2.shape[0])
            animal_means2.append(np.nanmean(snip2, axis=0))

    snippets = np.vstack(all_snippets) if all_snippets else empty_snippets()
    snippets2 = np.vstack(all_snippets2) if all_snippets2 else empty_snippets()
    means = np.vstack(animal_means) if animal_means else empty_snippets()
    means2 = np.vstack(animal_means2) if animal_means2 else empty_snippets()
    return snippets, snippets2, animal_boundaries, animal_boundaries2, means, means2


def extract_snippets_single(
    T: pd.DataFrame,
    event_times: np.ndarray,
    n_bl_start: int,
    n_post: int,
    n_total_full: int,
    bl_idx: np.ndarray,
    disp_idx: np.ndarray,
    has_second_signal: bool,
) -> tuple[np.ndarray, np.ndarray]:
    time = T["time"].to_numpy(dtype=float)
    if has_second_signal:
        snippets = extract_channel_snippets(
            time, T["zsc_exp"].to_numpy(dtype=float), event_times, n_bl_start, n_post, n_total_full, bl_idx, disp_idx
        )
        snippets2 = extract_channel_snippets(
            time, T["zsc_exp2"].to_numpy(dtype=float), event_times, n_bl_start, n_post, n_total_full, bl_idx, disp_idx
        )
    else:
        snippets = extract_channel_snippets(
            time, get_single_signal_trace(T), event_times, n_bl_start, n_post, n_total_full, bl_idx, disp_idx
        )
        snippets2 = empty_snippets()
    return snippets, snippets2


def extract_channel_snippets(
    time: np.ndarray,
    trace: np.ndarray,
    event_times: np.ndarray,
    n_bl_start: int,
    n_post: int,
    n_total_full: int,
    bl_idx: np.ndarray,
    disp_idx: np.ndarray,
) -> np.ndarray:
    if trace.size == 0 or len(event_times) == 0:
        return empty_snippets()
    snippets_full = np.full((len(event_times), n_total_full), np.nan, dtype=float)
    for i, event_time in enumerate(event_times):
        idx = int(np.argmin(np.abs(time - event_time)))
        start = idx - n_bl_start
        end = idx + n_post
        if start >= 0 and end < len(trace):
            snippets_full[i, :] = trace[start : end + 1]

    valid = ~np.any(np.isnan(snippets_full), axis=1)
    snippets_full = snippets_full[valid, :]
    if len(snippets_full) == 0:
        return empty_snippets()
    bl_mean = np.mean(snippets_full[:, bl_idx], axis=1, keepdims=True)
    return snippets_full[:, disp_idx] - bl_mean


def get_single_signal_trace(T: pd.DataFrame) -> np.ndarray:
    if has_valid_channel(T, "zsc_exp2"):
        return T["zsc_exp2"].to_numpy(dtype=float)
    if has_valid_channel(T, "zsc_exp"):
        return T["zsc_exp"].to_numpy(dtype=float)
    return np.array([])


def has_valid_channel(T: pd.DataFrame, field_name: str) -> bool:
    return field_name in T.columns and np.any(np.isfinite(T[field_name].to_numpy(dtype=float)))


def has_two_signal_data(session: dict[str, Any]) -> bool:
    metadata = session["metadata"]
    if "has_second_signal" in metadata:
        return bool(metadata["has_second_signal"])
    T = session["T"]
    return has_valid_channel(T, "zsc_exp") and has_valid_channel(T, "zsc_exp2")


def plot_stimulus(ax: plt.Axes, pat: dict[str, Any], pre: float, post: float) -> None:
    if pat["ramp"] is not None:
        pulse_times = pat["ramp"]
    else:
        n_pulses = int(pat["dur"] * pat["freq"])
        pulse_times = np.linspace(0, pat["dur"], n_pulses + 1)[:-1]
    for pulse_time in pulse_times:
        ax.plot([pulse_time, pulse_time], [0, 1], color="r", lw=1.5)
    ax.set_xlim([-pre, post])
    ax.set_ylim([-0.2, 1.3])
    ax.set_yticks([])
    ax.tick_params(labelbottom=False)
    ax.set_title(pat["label"])
    ax.spines[["top", "right"]].set_visible(False)


def plot_heatmap(ax: plt.Axes, snippets: np.ndarray, t_axis: np.ndarray, animal_boundaries: list[int]) -> None:
    if len(snippets):
        ax.imshow(
            snippets,
            aspect="auto",
            interpolation="nearest",
            extent=[t_axis[0], t_axis[-1], snippets.shape[0] + 0.5, 0.5],
            cmap="viridis",
        )
        ax.axvline(0, color="w", ls="--", lw=1)
        for boundary in animal_boundaries[1:-1]:
            ax.axhline(boundary + 0.5, color="r", lw=2)


def plot_psth(
    ax: plt.Axes,
    t_axis: np.ndarray,
    snippets: np.ndarray,
    animal_means: np.ndarray,
    view_mode: str,
    color: str,
) -> bool:
    if len(animal_means) == 0:
        return False
    if view_mode == "single":
        avg_source = snippets
    else:
        avg_source = animal_means
        for row in animal_means:
            ax.plot(t_axis, row, color=(0, 0, 0, 0.4), lw=0.5)
    avg = np.nanmean(avg_source, axis=0)
    sem = sem_rows(avg_source)
    ax.fill_between(t_axis, avg + sem, avg - sem, color=color, alpha=0.3, linewidth=0)
    ax.plot(t_axis, avg, color=color, lw=1.5)
    return True


def add_psth_reference_lines(axs: list[plt.Axes], x_values: range, y_values: range) -> None:
    for ax in axs:
        xlim = ax.get_xlim()
        ylim = ax.get_ylim()
        for x_val in x_values:
            if xlim[0] <= x_val <= xlim[1]:
                ax.axvline(x_val, ls="--", color=GUIDE_COLOR, lw=0.75)
        for y_val in y_values:
            if ylim[0] <= y_val <= ylim[1]:
                ax.axhline(y_val, ls="--", color=GUIDE_COLOR, lw=0.75)


def sem_rows(values: np.ndarray) -> np.ndarray:
    if len(values) <= 1:
        return np.zeros(values.shape[1], dtype=float)
    return np.nanstd(values, axis=0, ddof=1) / np.sqrt(values.shape[0])


def empty_snippets() -> np.ndarray:
    return np.empty((0, 0), dtype=float)


if __name__ == "__main__":
    main()
