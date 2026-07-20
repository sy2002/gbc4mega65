"""Optional release hooks for gbc4mega65.

The generic make_release.py imports this module when present. Keep release
policy in CORE/release.toml whenever possible; use hooks only for checks or
artifacts that cannot be expressed declaratively.
"""

from datetime import date
import posixpath
from pathlib import Path
import re
import shutil
from urllib.parse import urlsplit, urlunsplit


# Documentation copied into a release by this hook. Keys are paths in the
# repository and values are their paths in the release folder. Keeping this as
# one map lets the Markdown link rewriter decide whether a relative link can
# stay local or must point at the develop branch on GitHub. Documentation
# copied by make_release.py itself is added to that map separately below.
RELEASE_DOCUMENTS = {
    Path("README.md"): Path("README.md"),
    Path("doc/joystick.md"): Path("doc/joystick.md"),
    Path("doc/colormodes.md"): Path("doc/colormodes.md"),
    Path("doc/bootroms.md"): Path("doc/bootroms.md"),
    Path("doc/video_modes.md"): Path("doc/video_modes.md"),
    Path("doc/developers.md"): Path("doc/developers.md"),
}

RELEASE_ASSETS = {
    Path("doc/gb-and-gbc.jpg"): Path("doc/gb-and-gbc.jpg"),
    Path("doc/00-main.jpg"): Path("doc/00-main.jpg"),
    Path("doc/01-game-boy-tetris.png"): Path("doc/01-game-boy-tetris.png"),
    Path("doc/02-game-boy-super-mario-land.png"): Path("doc/02-game-boy-super-mario-land.png"),
    Path("doc/03-game-boy-color-yoshis-cookie.png"): Path(
        "doc/03-game-boy-color-yoshis-cookie.png"
    ),
    Path("doc/04-game-boy-color-castlevania-the-adventure.png"): Path(
        "doc/04-game-boy-color-castlevania-the-adventure.png"
    ),
    Path("doc/05-game-boy-color-elmo-in-grouchland.png"): Path(
        "doc/05-game-boy-color-elmo-in-grouchland.png"
    ),
    Path("doc/gbc07.jpg"): Path("doc/gbc07.jpg"),
    Path("doc/gbc08.jpg"): Path("doc/gbc08.jpg"),
    Path("doc/gbc09.jpg"): Path("doc/gbc09.jpg"),
}

GITHUB_DEVELOP_BLOB = "https://github.com/sy2002/gbc4mega65/blob/develop/"

# Inline Markdown links and images. The repository documentation currently
# uses plain destinations (with optional titles), which deliberately keeps
# this narrower and safer than attempting to parse all of Markdown.
MARKDOWN_LINK_RE = re.compile(
    r"(?P<prefix>!?\[[^\]\n]*\]\()"
    r"(?P<open><)?(?P<target>[^)\s>]+)(?(open)>)"
    r"(?P<suffix>(?:\s+(?:\"[^\"\n]*\"|'[^'\n]*'|\([^\)\n]*\)))?\))"
)

ALPHA_VERSION_RE = re.compile(
    r"^WIP-V(?P<major>\d+)-A(?P<alpha>\d+)(?:X(?P<iteration>[1-9]\d*))?$"
)
BETA_VERSION_RE = re.compile(
    r"^WIP-V(?P<major>\d+)-B(?P<beta>\d+)(?:X(?P<iteration>[1-9]\d*))?$"
)
MAJOR_VERSION_RE = re.compile(r"^V(?P<major>\d+)$")
MINOR_VERSION_RE = re.compile(r"^V(?P<major>\d+)\.(?P<minor>\d+)$")


def validate(ctx):
    """Run core-specific validation before the output folder is written."""
    return None


def _release_notes_title(version, today):
    """Build the dated first line used in the packaged VERSIONS.md."""
    formatted_date = f"{today.strftime('%B')} {today.day}, {today.year}"

    match = ALPHA_VERSION_RE.fullmatch(version)
    if match:
        alpha = match.group("alpha")
        if match.group("iteration"):
            alpha += f"X{match.group('iteration')}"
        return (
            f"Alpha {alpha} for Version {match.group('major')} - "
            f"{formatted_date}"
        )

    match = BETA_VERSION_RE.fullmatch(version)
    if match:
        beta = match.group("beta")
        if match.group("iteration"):
            beta += f"X{match.group('iteration')}"
        return (
            f"Beta {beta} for Version {match.group('major')} - "
            f"{formatted_date}"
        )

    match = MINOR_VERSION_RE.fullmatch(version)
    if match:
        release = f"{match.group('major')}.{match.group('minor')}"
        return f"Version {release} - {formatted_date}"

    match = MAJOR_VERSION_RE.fullmatch(version)
    if match:
        return f"Version {match.group('major')} - {formatted_date}"

    # --ignore permits ad-hoc version names. Still give such packages a useful
    # dated heading instead of leaving the source placeholder in place.
    return f"{version} - {formatted_date}"


def _rewrite_target(target, source_path, release_path, local_files):
    """Rewrite one Markdown destination for its location in the release."""
    parsed = urlsplit(target)
    if parsed.scheme or parsed.netloc or not parsed.path or target.startswith("#"):
        return target

    # Markdown paths use POSIX separators on every host. Resolve relative to
    # the source document.
    if parsed.path.startswith("/"):
        repository_target = posixpath.normpath(parsed.path.lstrip("/"))
    else:
        repository_target = posixpath.normpath(
            posixpath.join(source_path.parent.as_posix(), parsed.path)
        )

    if repository_target == ".." or repository_target.startswith("../"):
        return target

    mapped_target = local_files.get(repository_target)
    if mapped_target is not None:
        release_parent = release_path.parent.as_posix() or "."
        new_path = posixpath.relpath(mapped_target, start=release_parent)
    else:
        new_path = GITHUB_DEVELOP_BLOB + repository_target

    return urlunsplit(("", "", new_path, parsed.query, parsed.fragment))


def _rewrite_markdown_links(text, source_path, release_path, local_files):
    """Make repository-relative Markdown links work from the release tree."""
    def replace(match):
        target = _rewrite_target(
            match.group("target"), source_path, release_path, local_files
        )
        open_angle = "<" if match.group("open") else ""
        close_angle = ">" if match.group("open") else ""
        return (
            match.group("prefix") + open_angle + target + close_angle
            + match.group("suffix")
        )

    return MARKDOWN_LINK_RE.sub(replace, text)


def _write_document(ctx, source_path, release_path, local_files, *, title=None):
    """Write one transformed Markdown document and preserve its timestamp."""
    src = ctx.repo / source_path
    if not src.is_file():
        ctx.die(f"Required release documentation not found: {source_path}")

    text = src.read_text(encoding="utf-8")
    if title is not None:
        lines = text.splitlines(keepends=True)
        if not lines:
            ctx.die(f"Required release documentation is empty: {source_path}")
        newline = "\n" if lines[0].endswith("\n") else ""
        lines[0] = title + newline
        text = "".join(lines)

    text = _rewrite_markdown_links(
        text, source_path, release_path, local_files
    )
    dst = ctx.out / release_path
    dst.parent.mkdir(parents=True, exist_ok=True)
    dst.write_text(text, encoding="utf-8")
    shutil.copystat(src, dst)
    return dst


def after_package(ctx):
    """Copy core-specific documentation into the release folder.

    Returns the destination paths so make_release.py lists them in the release
    summary. Required source files abort packaging if they are missing.
    """
    artifacts = []

    local_files = {
        source.as_posix(): destination.as_posix()
        for source, destination in (RELEASE_DOCUMENTS | RELEASE_ASSETS).items()
    }

    # make_release.py has already copied VERSIONS.md according to release.toml.
    # Rewrite it here so the packaged copy has a release-specific heading and
    # its remaining repository-relative links work outside a checkout.
    _write_document(
        ctx,
        Path("VERSIONS.md"),
        Path("VERSIONS.md"),
        local_files,
        title=_release_notes_title(ctx.version, date.today()),
    )

    for source, destination in RELEASE_DOCUMENTS.items():
        artifacts.append(
            _write_document(ctx, source, destination, local_files)
        )

    for source, destination in RELEASE_ASSETS.items():
        src = ctx.repo / source
        if not src.is_file():
            ctx.die(f"Required release documentation asset not found: {source}")
        dst = ctx.out / destination
        ctx.copy_preserving_timestamps(src, dst)
        artifacts.append(dst)

    return artifacts
