"""Raw FIP loading helpers for the experiment Python port.

The first loader path uses the vendored GitHub Fipster Python package.  The
fallback parser mirrors the minimal behavior used by ``extract_fip_raw.m`` and
the legacy MATLAB ``FIP_signal`` class.
"""

from __future__ import annotations

from dataclasses import dataclass
from pathlib import Path
import sys
from typing import Any

import h5py
import numpy as np
import pandas as pd
from scipy.io import loadmat


VENDORED_FIPSTER = Path(__file__).resolve().parent / "vendor" / "Fipster_python"
VENDORED_SRC = VENDORED_FIPSTER / "src"


@dataclass
class RawFipData:
    time: np.ndarray
    sig: list[np.ndarray]
    ref: list[np.ndarray]
    logai: pd.DataFrame | None
    source: str


def load_raw_fip(filename: str | Path) -> RawFipData:
    """Load FIP data, preferring vendored Fipster and falling back locally."""

    filename = Path(filename).expanduser()
    try:
        return _load_with_vendored_fipster(filename)
    except Exception as exc:
        print(f"Vendored Fipster loader failed ({exc}); using fallback parser.")
        return _load_with_fallback_parser(filename)


def _load_with_vendored_fipster(filename: Path) -> RawFipData:
    if not VENDORED_SRC.is_dir():
        raise FileNotFoundError(f"Missing vendored Fipster source at {VENDORED_SRC}")
    if str(VENDORED_SRC) not in sys.path:
        sys.path.insert(0, str(VENDORED_SRC))

    import fipster  # type: ignore

    signal = fipster.FIP_signal(filename=str(filename))
    if not getattr(signal, "hasdata", False):
        raise RuntimeError("Fipster did not load data.")

    sig_array = np.asarray(signal.signal, dtype=float)
    ref_array = np.asarray(signal.raw_ref, dtype=float)
    if sig_array.ndim != 3 or sig_array.shape[0] < 2:
        raise RuntimeError(f"Unexpected Fipster signal shape: {sig_array.shape}")
    if ref_array.ndim != 3 or ref_array.shape[0] < 2:
        raise RuntimeError(f"Unexpected Fipster ref shape: {ref_array.shape}")

    n_signals = sig_array.shape[2]
    time = np.asarray(sig_array[1, :, 0], dtype=float)
    sig = [np.asarray(sig_array[0, :, i], dtype=float) for i in range(n_signals)]
    ref = [np.asarray(ref_array[0, :, i], dtype=float) for i in range(n_signals)]

    logai = getattr(signal, "logAI", None)
    if isinstance(logai, pd.DataFrame) and not logai.empty:
        logai = logai.copy()
        logai = logai.rename(columns={logai.columns[0]: "time"})
    else:
        logai = _load_logai(filename)

    return RawFipData(time=time, sig=sig, ref=ref, logai=logai, source="vendored_fipster")


def _load_with_fallback_parser(filename: Path) -> RawFipData:
    data = _read_mat_file(filename)
    logai = _load_logai(filename)

    if "sig" in data:
        sig_raw = _as_2d(np.asarray(data["sig"], dtype=float))
        ref_raw = _as_2d(np.asarray(data["ref"], dtype=float))
        sig_raw = sig_raw[:-5, :]
        ref_raw = ref_raw[:-5, :]
        framerate = float(np.asarray(data["framerate"]).squeeze()) / 2.0
        time = np.arange(sig_raw.shape[0], dtype=float) / framerate
        sig = [sig_raw[:, i] for i in range(sig_raw.shape[1])]
        ref = [ref_raw[:, i] for i in range(ref_raw.shape[1])]
        return RawFipData(time=time, sig=sig, ref=ref, logai=logai, source="fallback_sig_ref")

    if "signal" in data:
        signal_raw = np.asarray(data["signal"], dtype=float)
        ref_raw = np.asarray(data["ref"], dtype=float) if "ref" in data else None
        time, sig, ref = _unpack_fip_acquisition(signal_raw, ref_raw)
        return RawFipData(time=time, sig=sig, ref=ref, logai=logai, source="fallback_signal_ref")

    raise ValueError(f"Unsupported FIP .mat format in {filename}")


def _read_mat_file(filename: Path) -> dict[str, Any]:
    try:
        return {k: v for k, v in loadmat(filename, squeeze_me=False).items() if not k.startswith("__")}
    except NotImplementedError:
        return _read_hdf5_mat_file(filename)
    except ValueError as exc:
        if "Unknown mat file type" not in str(exc):
            raise
        return _read_hdf5_mat_file(filename)


def _read_hdf5_mat_file(filename: Path) -> dict[str, Any]:
    out: dict[str, Any] = {}
    with h5py.File(filename, "r") as h5:
        for key, value in h5.items():
            if isinstance(value, h5py.Dataset):
                out[key] = np.array(value[()])
    return out


def _unpack_fip_acquisition(
    signal_raw: np.ndarray,
    ref_raw: np.ndarray | None,
) -> tuple[np.ndarray, list[np.ndarray], list[np.ndarray]]:
    if signal_raw.ndim == 2:
        signal_raw = signal_raw[:, :, np.newaxis]
    if signal_raw.shape[1] < 2 and signal_raw.shape[0] >= 2:
        signal_raw = np.swapaxes(signal_raw, 0, 1)

    time = np.asarray(signal_raw[:, 1, 0], dtype=float)
    sig = [np.asarray(signal_raw[:, 0, i], dtype=float) for i in range(signal_raw.shape[2])]

    if ref_raw is None or ref_raw.size == 0:
        ref = [np.full_like(time, np.nan, dtype=float) for _ in sig]
        return time, sig, ref

    if ref_raw.ndim == 2:
        ref_raw = ref_raw[:, :, np.newaxis]
    if ref_raw.shape[1] < 2 and ref_raw.shape[0] >= 2:
        ref_raw = np.swapaxes(ref_raw, 0, 1)

    ref: list[np.ndarray] = []
    for i in range(min(ref_raw.shape[2], len(sig))):
        ref_time = np.asarray(ref_raw[:, 1, i], dtype=float)
        ref_value = np.asarray(ref_raw[:, 0, i], dtype=float)
        finite = np.isfinite(ref_time) & np.isfinite(ref_value)
        if finite.sum() < 2:
            ref.append(np.full_like(time, np.nan, dtype=float))
            continue
        interp_ref = np.interp(time, ref_time[finite], ref_value[finite])
        ref.append(interp_ref)

    while len(ref) < len(sig):
        ref.append(np.full_like(time, np.nan, dtype=float))
    return time, sig, ref


def _load_logai(filename: Path) -> pd.DataFrame | None:
    logai_file = filename.with_name(f"{filename.stem}_logAI.csv")
    if not logai_file.is_file():
        return None

    logai = pd.read_csv(logai_file, header=None)
    numeric = logai.apply(pd.to_numeric, errors="coerce")
    keep = numeric.max(axis=0, skipna=True) > 1
    if not keep.empty:
        keep.iloc[0] = True
    numeric = numeric.loc[:, keep].copy()
    if numeric.empty or numeric.shape[1] < 2:
        return None

    numeric.columns = ["time"] + [f"ttl_{i}" for i in range(1, numeric.shape[1])]
    last_time = numeric["time"].iloc[-1]
    if np.isfinite(last_time):
        numeric["time"] = np.linspace(0, float(last_time), len(numeric))
    return numeric


def _as_2d(values: np.ndarray) -> np.ndarray:
    values = np.asarray(values, dtype=float)
    if values.ndim == 1:
        return values[:, np.newaxis]
    return values
