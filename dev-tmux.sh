#!/bin/bash

mkdir -p dist

tmux rename-window 'teleidoscope/dev'

tmux send-keys '. venv/bin/activate' 'C-m'
tmux send-keys 'HOST="0.0.0.0" python -m teleidoscope' 'C-m'

cd frontend

tmux split-window -h
tmux send-keys '. ../venv/bin/activate' 'C-m'
tmux send-keys 'find . -name "*.nim" | entr -s "nimble build"' 'C-m'

tmux split-window
tmux send-keys '. ../venv/bin/activate' 'C-m'
tmux send-keys 'nimble bundle' 'C-m'
