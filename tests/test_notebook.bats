#!/usr/bin/env bats

load "../lib/log.sh"
# Mocking Python calls by defining uv function if needed, or ensuring it doesn't fail
# For unit testing bash logic, we want to avoid actual heavy calls if possible.
# But sourceing notebook.sh calls nothing.

load "../lib/python.sh"
load "../lib/notebook.sh"

setup() {
    export LOG_FILE="/dev/null"
}

@test "find_notebook detects existing notebook" {
    # Create a dummy notebook
    touch dummy_test.ipynb
    
    # Needs to capture internal variable NOTEBOOK, but find_notebook sets a global NOTEBOOK variable?
    # Yes, NOTEBOOK is global.
    
    # We can invoke find_notebook and check output
    run find_notebook
    
    rm dummy_test.ipynb
    
    [ "$status" -eq 0 ]
    [[ "$output" == *"First notebook found"* ]]
}
