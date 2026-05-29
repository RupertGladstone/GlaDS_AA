#!/usr/bin/env bash
# Install ParaView 6.1.1 (official Linux binary) with ADIOS2 support
#
# Tested on Ubuntu 22.04 LTS x86_64.
# No sudo required (except stage 1 prerequisite) — installs entirely into
# your home directory.
# After installation, pvpython and paraview are in ~/ParaView-6.1.1-.../bin/
#
# ADIOS2 is bundled in the official binary — stage 1 alone is sufficient
# if you only need to view ADIOS2 files interactively in the ParaView GUI.
#
# Stages 2 and 3 (Miniforge + conda environment) are only needed for
# standalone Python scripting outside ParaView (e.g. meshio, pyproj, adios2).
#
# Usage:
#   bash install_paraview_adios2.sh

set -e  # exit immediately on any error


# ── 1. System dependency: libxcb-cursor0 (required by Qt 6.5+ for GUI) ────────
# Required for the ParaView GUI to start. Needs sudo.

sudo apt install -y libxcb-cursor0


# ── 2. Official ParaView binary (includes ADIOS2) ─────────────────────────────

PV_VERSION="6.1.1"
PV_TARBALL="ParaView-${PV_VERSION}-MPI-Linux-Python3.12-x86_64.tar.gz"
PV_URL="https://www.paraview.org/files/v6.1/${PV_TARBALL}"
PV_INSTALL_DIR="${HOME}/ParaView-${PV_VERSION}-MPI-Linux-Python3.12-x86_64"

if [ -d "$PV_INSTALL_DIR" ]; then
    echo "ParaView already installed at $PV_INSTALL_DIR — skipping download."
else
    echo "Downloading ParaView ${PV_VERSION} (~827 MB)..."
    wget -q --show-progress -O /tmp/${PV_TARBALL} ${PV_URL}

    echo "Extracting..."
    tar -xzf /tmp/${PV_TARBALL} -C ${HOME}

    echo "Cleaning up tarball..."
    rm /tmp/${PV_TARBALL}
fi

echo "ParaView binary: ${PV_INSTALL_DIR}/bin/paraview"
echo "pvpython:        ${PV_INSTALL_DIR}/bin/pvpython"


# ── 3. Add ParaView to PATH ───────────────────────────────────────────────────
# Prepend to PATH in ~/.bashrc so this version takes priority over any older
# system-installed ParaView. Has no effect if the line is already present.

PV_PATH_LINE="export PATH=\"${PV_INSTALL_DIR}/bin:\$PATH\""
if grep -qF "${PV_INSTALL_DIR}/bin" "${HOME}/.bashrc"; then
    echo "PATH entry already present in ~/.bashrc — skipping."
else
    echo "" >> "${HOME}/.bashrc"
    echo "# ParaView ${PV_VERSION} (with ADIOS2)" >> "${HOME}/.bashrc"
    echo "${PV_PATH_LINE}" >> "${HOME}/.bashrc"
    echo "Added ParaView to PATH in ~/.bashrc"
fi


# ── 4. Miniforge (lightweight conda using conda-forge by default) ──────────────

MINIFORGE_DIR="${HOME}/miniforge3"

if [ -d "$MINIFORGE_DIR" ]; then
    echo "Miniforge already installed at $MINIFORGE_DIR — skipping."
else
    echo "Downloading Miniforge installer..."
    wget -q --show-progress -O /tmp/Miniforge3.sh \
        https://github.com/conda-forge/miniforge/releases/latest/download/Miniforge3-Linux-x86_64.sh

    echo "Installing Miniforge to ${MINIFORGE_DIR}..."
    bash /tmp/Miniforge3.sh -b -p ${MINIFORGE_DIR}
    rm /tmp/Miniforge3.sh
fi

CONDA="${MINIFORGE_DIR}/bin/conda"


# ── 5. Python environment for scripted processing ─────────────────────────────
# Includes: meshio (VTU reading), pyproj (coordinate conversion), adios2 (ADIOS2 output)
# Note: the conda 'paraview' package exists but is built without ADIOS2 —
#       use the official binary above for any ADIOS2 work in the GUI or pvpython.

ENV_NAME="paraview"

if ${CONDA} env list | grep -q "^${ENV_NAME} "; then
    echo "Conda environment '${ENV_NAME}' already exists — skipping creation."
else
    echo "Creating conda environment '${ENV_NAME}' with meshio, pyproj, adios2, cartopy, matplotlib..."
    ${CONDA} create -n ${ENV_NAME} -c conda-forge meshio pyproj adios2 cartopy matplotlib -y
fi


# ── 6. Verify ─────────────────────────────────────────────────────────────────

echo ""
echo "=== Verification ==="
${PV_INSTALL_DIR}/bin/pvpython -c "
import paraview
print('ParaView version:', paraview.__version__)
from paraview.simple import *
import paraview.servermanager as sm
adios = [k for k in dir(sm.sources) if 'adios' in k.lower()]
print('ADIOS2 readers available:', adios)
"

${MINIFORGE_DIR}/envs/${ENV_NAME}/bin/python -c "
import meshio, pyproj, adios2, cartopy, matplotlib
print('meshio:', meshio.__version__)
print('pyproj:', pyproj.__version__)
print('adios2:', adios2.__version__)
print('cartopy:', cartopy.__version__)
print('matplotlib:', matplotlib.__version__)
"

echo ""
echo "Installation complete."
echo ""
echo "To use pvpython:  ${PV_INSTALL_DIR}/bin/pvpython"
echo "To use ParaView GUI: ${PV_INSTALL_DIR}/bin/paraview"
echo "To activate Python scripting environment: conda activate ${ENV_NAME}"
echo "  (run 'conda init' first if 'conda' is not found in your shell)"
