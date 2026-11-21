"""Set up the 18 recordings used by the C247A single-user configuration."""

import argparse
import re
import shutil
import tempfile
from pathlib import Path
from urllib.request import urlopen
from zipfile import BadZipFile, ZipFile


BOX_FOLDER_URL = "https://ucla.app.box.com/s/3xc4nwpfjfpo6ydjs94t0v2kuq37d5eg"
RECORDING_COUNT = 18


def recording_present(path: Path) -> bool:
    return path.is_file() and path.stat().st_size > 0


def stage_recordings(archive_path: Path, staging: Path, missing: set[str]) -> None:
    with ZipFile(archive_path) as archive:
        members = {}
        for member in archive.infolist():
            name = Path(member.filename).name
            if name in missing and not member.is_dir() and member.file_size:
                if name in members:
                    raise ValueError(f"ZIP contains more than one copy of {name}")
                members[name] = member

        absent = sorted(missing - members.keys())
        if absent:
            raise ValueError(
                "ZIP is missing required recordings:\n  " + "\n  ".join(absent)
            )

        for name, member in members.items():
            with (
                archive.open(member) as recording,
                (staging / name).open("wb") as output,
            ):
                shutil.copyfileobj(recording, output)


def main() -> None:
    parser = argparse.ArgumentParser(
        description=__doc__,
        epilog=f"Download the folder as a ZIP from Box at {BOX_FOLDER_URL}",
    )
    parser.add_argument(
        "source", nargs="?", help="Path to the ZIP or a direct HTTPS archive URL"
    )
    source = parser.parse_args().source

    repo_dir = Path(__file__).resolve().parents[1]
    # Matches config/base.yaml when training starts from the repository root.
    data_dir = repo_dir / "data"
    config = repo_dir / "config/user/single_user.yaml"
    sessions = re.findall(
        r"^[ \t]*session:[ \t]+([\w@-]+)[ \t]*$",
        config.read_text(encoding="utf-8"),
        re.MULTILINE,
    )
    required = {f"{session}.hdf5" for session in sessions}
    if len(required) != RECORDING_COUNT:
        parser.exit(1, f"Expected {RECORDING_COUNT} distinct recordings in {config}.\n")

    missing = {name for name in required if not recording_present(data_dir / name)}
    if not missing:
        print(f"All {RECORDING_COUNT} recordings are already in {data_dir}.")
        return

    if source is None:
        parser.exit(
            1,
            f"{len(missing)} recordings are missing. {parser.epilog}\n"
            "Then run python3 scripts/setup_data.py /path/to/downloaded.zip\n",
        )

    try:
        data_dir.mkdir(exist_ok=True)
        with tempfile.TemporaryDirectory(
            prefix=".setup_data-", dir=data_dir
        ) as temp_dir:
            staging = Path(temp_dir)
            if source.startswith("https://"):
                print("Downloading dataset archive...", flush=True)
                archive_path = staging / "recordings.zip"
                with (
                    urlopen(source, timeout=60) as response,
                    archive_path.open("wb") as output,
                ):
                    shutil.copyfileobj(response, output)
            else:
                archive_path = Path(source).expanduser()

            stage_recordings(archive_path, staging, missing)
            for name in missing:
                destination = data_dir / name
                if not recording_present(destination):
                    (staging / name).replace(destination)
    except (BadZipFile, OSError, ValueError) as error:
        parser.exit(1, f"Dataset setup failed. {error}\n")

    if not all(recording_present(data_dir / name) for name in required):
        parser.exit(
            1, "Dataset setup is incomplete. Run the script again with the ZIP.\n"
        )
    print(f"Verified all {RECORDING_COUNT} recordings in {data_dir}.")


if __name__ == "__main__":
    main()
