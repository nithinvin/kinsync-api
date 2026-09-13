#!/bin/bash

# ANSI color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m' # No Color

script_path=$(readlink -f $0)
qa_path=$(dirname "$script_path")
static_analysis_path=${qa_path}/static_analysis
package_path=${qa_path}/..
overall_result=0
run_component_tests=0

# Parse arguments
for arg in "$@"; do
    case "$arg" in
        --component)
            run_component_tests=1
            ;;
    esac
done

# --- Result tracking ---------------------------------------------------------
# Each step appends a line to a temp file: "name<TAB>result<TAB>elapsed"
summary_file=$(mktemp)
overall_result=0

# Portable millisecond timestamp (uses nanosecond epoch, divided by 1 000 000).
# Falls back to second-precision on systems without %N support (e.g. macOS).
now_ms()
{
    ns=$(date +%s%N 2>/dev/null)
    if [ ${#ns} -gt 15 ]; then
        echo $(( ns / 1000000 ))
    else
        echo $(( $(date +%s) * 1000 ))
    fi
}

record_step()
{
    name="$1"
    result="$2"
    elapsed="$3"
    printf '%s\t%s\t%s\n' "$name" "$result" "$elapsed" >> "$summary_file"

    if [ "$result" -eq 0 ]; then
        echo -e "${GREEN}PASS${NC}: ${name} (${elapsed} ms)"
    else
        echo -e "${RED}FAIL${NC}: ${name} (${elapsed} ms)"
        overall_result=1
    fi
}

# --- Individual steps --------------------------------------------------------

run_ruff()
{
    echo ""
    echo -e "${CYAN}${BOLD}[ruff — format + lint (--fix)]${NC}"
    start=$(now_ms)
    # Format first (always exits 0, may reformat files in-place).
    ruff --config ${package_path}/qa_tools/static_analysis/ruff.toml format ${package_path} > /dev/null 2>&1
    # Lint with auto-fix; exits non-zero only if unfixable violations remain.
    output=$(ruff --config ${package_path}/qa_tools/static_analysis/ruff.toml check --fix ${package_path} 2>&1)
    rc=$?
    elapsed=$(( $(now_ms) - start ))
    if [ "$rc" -ne 0 ]; then
        echo "$output"
    else
        echo "$output" | tail -1
    fi
    record_step "ruff" "$rc" "$elapsed"
}

run_bandit()
{
    echo ""
    echo -e "${CYAN}${BOLD}[bandit — security lint]${NC}"
    start=$(now_ms)
    output=$(bandit -r ${package_path}/*.py ${package_path}/internal/ -q 2>&1)
    rc=$?
    elapsed=$(( $(now_ms) - start ))
    if [ "$rc" -ne 0 ]; then
        echo "$output"
    else
        echo "No issues identified."
    fi
    record_step "bandit" "$rc" "$elapsed"
}

run_pylint_main()
{
    echo ""
    file_count=$(ls ${package_path}/*.py 2>/dev/null | wc -l | tr -d ' ')
    echo -e "${CYAN}${BOLD}[pylint — main scripts] (${file_count} files)${NC}"
    start=$(now_ms)
    output=$(pylint --rcfile=${static_analysis_path}/pylintrc ${package_path}/*.py 2>&1)
    rc=$?
    elapsed=$(( $(now_ms) - start ))
    if [ "$rc" -ne 0 ]; then
        echo "$output"
    else
        echo "$output" | tail -3
    fi
    record_step "pylint (main)" "$rc" "$elapsed"
}

run_pylint_internal()
{
    echo ""
    file_count=$(ls ${package_path}/internal/*.py 2>/dev/null | wc -l | tr -d ' ')
    echo -e "${CYAN}${BOLD}[pylint — internal] (${file_count} files)${NC}"
    start=$(now_ms)
    output=$(pylint --rcfile=${static_analysis_path}/pylintrc ${package_path}/internal 2>&1)
    rc=$?
    elapsed=$(( $(now_ms) - start ))
    if [ "$rc" -ne 0 ]; then
        echo "$output"
    else
        echo "$output" | tail -3
    fi
    record_step "pylint (internal)" "$rc" "$elapsed"
}

run_mypy_main()
{
    echo ""
    echo -e "${CYAN}${BOLD}[mypy — main scripts]${NC}"
    start=$(now_ms)
    output=$(mypy --config-file ${static_analysis_path}/mypy_config ${package_path}/*.py 2>&1)
    rc=$?
    elapsed=$(( $(now_ms) - start ))
    if [ "$rc" -ne 0 ]; then
        echo "$output"
    else
        echo "$output" | tail -1
    fi
    record_step "mypy (main)" "$rc" "$elapsed"
}

run_mypy_internal()
{
    echo ""
    echo -e "${CYAN}${BOLD}[mypy — internal]${NC}"
    start=$(now_ms)
    output=$(mypy --config-file ${static_analysis_path}/mypy_config ${package_path}/internal/*.py 2>&1)
    rc=$?
    elapsed=$(( $(now_ms) - start ))
    if [ "$rc" -ne 0 ]; then
        echo "$output"
    else
        echo "$output" | tail -1
    fi
    record_step "mypy (internal)" "$rc" "$elapsed"
}

run_pylint_tests()
{
    echo ""
    file_count=$(ls ${package_path}/tests/test_*.py 2>/dev/null | wc -l | tr -d ' ')
    echo -e "${CYAN}${BOLD}[pylint — tests] (${file_count} files)${NC}"
    start=$(now_ms)
    output=$(pylint --rcfile=${static_analysis_path}/pylintrc_tests ${package_path}/tests/ 2>&1)
    rc=$?
    elapsed=$(( $(now_ms) - start ))
    if [ "$rc" -ne 0 ]; then
        echo "$output"
    else
        echo "$output" | tail -3
    fi
    record_step "pylint (tests)" "$rc" "$elapsed"
}

run_mypy_tests()
{
    echo ""
    echo -e "${CYAN}${BOLD}[mypy — tests]${NC}"
    start=$(now_ms)
    output=$(mypy --config-file ${static_analysis_path}/mypy_config_tests ${package_path}/tests/*.py 2>&1)
    rc=$?
    elapsed=$(( $(now_ms) - start ))
    if [ "$rc" -ne 0 ]; then
        echo "$output"
    else
        echo "$output" | tail -1
    fi
    record_step "mypy (tests)" "$rc" "$elapsed"
}

run_radon()
{
    echo ""
    echo -e "${CYAN}${BOLD}[radon — cyclomatic complexity]${NC}"
    start=$(now_ms)
    output=$(radon cc ${package_path}/*.py ${package_path}/internal/ -n C -s 2>&1)
    rc=0
    if [ -n "$output" ]; then
        echo "$output"
        rc=1
    else
        echo "All functions below threshold (grade C)."
    fi
    elapsed=$(( $(now_ms) - start ))
    record_step "radon (cc)" "$rc" "$elapsed"
}

run_radon_mi()
{
    echo ""
    echo -e "${CYAN}${BOLD}[radon — maintainability index]${NC}"
    start=$(now_ms)
    output=$(radon mi ${package_path}/*.py ${package_path}/internal/ -n B -s 2>&1)
    rc=0
    if [ -n "$output" ]; then
        echo "$output"
        rc=1
    else
        echo "All files grade A."
    fi
    elapsed=$(( $(now_ms) - start ))
    record_step "radon (mi)" "$rc" "$elapsed"
}

run_cognitive_complexity()
{
    echo ""
    echo -e "${CYAN}${BOLD}[cognitive complexity]${NC}"
    start=$(now_ms)
    output=$(python3 ${qa_path}/check_cognitive_complexity.py \
        --max 15 ${package_path}/*.py ${package_path}/internal/ 2>&1)
    rc=$?
    elapsed=$(( $(now_ms) - start ))
    echo "$output"
    record_step "cognitive complexity" "$rc" "$elapsed"
}

run_cohesion()
{
    echo ""
    echo -e "${CYAN}${BOLD}[cohesion — class method/attribute usage (advisory)]${NC}"
    start=$(now_ms)
    output=$(python3 -m cohesion -f ${package_path}/internal/*.py ${package_path}/*.py \
        -b 50 2>&1)
    # Advisory only — never fails the build (Protocol/dataclass false positives).
    rc=0
    # Filter to only show classes that have a Total line
    flagged=$(echo "$output" | grep -B100 "Total:" | grep "Total:" | grep -v "File:" || true)
    if [ -n "$flagged" ]; then
        echo "$output" | awk '/Class:/{found=1} found{print} /Total:/{found=0}'
    else
        echo "All classes above 50% cohesion."
    fi
    elapsed=$(( $(now_ms) - start ))
    record_step "cohesion (advisory)" "$rc" "$elapsed"
}

run_tach()
{
    echo ""
    echo -e "${CYAN}${BOLD}[tach — module boundary check]${NC}"
    start=$(now_ms)
    output=$(cd ${package_path} && tach check 2>&1)
    rc=$?
    elapsed=$(( $(now_ms) - start ))
    if [ "$rc" -ne 0 ]; then
        echo "$output"
    else
        echo "All declared module boundaries respected."
    fi
    record_step "tach" "$rc" "$elapsed"
}

run_vulture()
{
    echo ""
    echo -e "${CYAN}${BOLD}[vulture — dead code (advisory, ≥80% confidence)]${NC}"
    start=$(now_ms)
    output=$(vulture ${package_path}/*.py ${package_path}/internal/ --min-confidence 80 2>&1)
    elapsed=$(( $(now_ms) - start ))
    # Advisory only — never fails the build.  Vulture has known false positives on
    # Protocol method definitions, dataclass fields, and functions only reachable via
    # callbacks or runtime dispatch.  Review findings before deleting any code.
    rc=0
    if [ -n "$output" ]; then
        echo "$output"
        echo "(advisory — review before removing; may include false positives)"
    else
        echo "No unused code found."
    fi
    record_step "vulture (advisory)" "$rc" "$elapsed"
}

run_unit_tests()
{
    echo ""
    echo -e "${CYAN}${BOLD}[unit tests + coverage]${NC}"
    start=$(now_ms)
    output=$(python3 -m pytest ${package_path}/tests/ \
        --ignore=${package_path}/tests/test_kinsync_component.py \
        -v \
        --cov-fail-under=90 \
        --cov=internal \
        --cov-config=${qa_path}/.coveragerc \
        --cov-branch \
        --cov-report=term-missing \
        --cov-report=html:${qa_path}/coverage_html_report 2>&1)
    rc=$?
    elapsed=$(( $(now_ms) - start ))
    test_summary=$(echo "$output" | grep -E '=+ .*(passed|failed|error).*=+' | tail -1 | sed 's/^[ =]*//;s/[ =]*$//')
    if [ "$rc" -ne 0 ]; then
        echo "$output"
    else
        # Show just the summary: coverage table + final line
        echo "$output" | awk '/^-+ coverage/,0'
    fi
    record_step "unit tests" "$rc" "$elapsed"
    if [ -n "$test_summary" ]; then
        echo -e "  Tests: ${test_summary}"
    fi
    if [ "$rc" -eq 0 ]; then
        echo -e "Coverage report: ${GREEN}${qa_path}/coverage_html_report/index.html${NC}"
    fi
}

run_component_tests()
{
    echo ""
    echo -e "${CYAN}${BOLD}[component tests]${NC}"
    echo -e "${YELLOW}Running against Neo4j server — this may take 30-40 seconds …${NC}"
    start=$(now_ms)
    # Stream output live (no capture) so each test prints as it completes.
    python3 -m pytest ${package_path}/tests/test_kinsync_component.py -v 2>&1 | \
        while IFS= read -r line; do echo "  $line"; done
    rc=${PIPESTATUS[0]}
    elapsed=$(( $(now_ms) - start ))
    record_step "component tests" "$rc" "$elapsed"
}

# --- Summary -----------------------------------------------------------------

print_summary()
{
    echo ""
    echo -e "${BOLD}===============================================${NC}"
    echo -e "${BOLD}  Summary${NC}"
    echo -e "${BOLD}===============================================${NC}"
    printf "  %-25s %-8s %s\n" "Step" "Result" "Time"
    echo "  -----------------------------------------------"

    while IFS='	' read -r name result elapsed; do
        if [ "$result" -eq 0 ] 2>/dev/null; then
            status="${GREEN}PASS${NC}"
        else
            status="${RED}FAIL${NC}"
        fi
        printf "  %-25s " "$name"
        printf "$status"
        printf "     %s ms\n" "$elapsed"
    done < "$summary_file"

    echo "  -----------------------------------------------"
    printf "  %-25s " "Overall"
    if [ "$overall_result" -eq 0 ]; then
        echo -e "${GREEN}${BOLD}ALL PASSED${NC}    ${total_elapsed} ms"
    else
        echo -e "${RED}${BOLD}FAILED${NC}        ${total_elapsed} ms"
    fi
    echo -e "${BOLD}===============================================${NC}"
    rm -f "$summary_file"
}

# --- Main --------------------------------------------------------------------

main()
{
    start_time=$(now_ms)

    # Ruff: format + auto-fix lint issues first, then static analysis.
    run_ruff
    run_bandit
    run_pylint_main
    run_pylint_internal
    run_mypy_main
    run_mypy_internal
    run_pylint_tests
    run_mypy_tests

    if [ "$overall_result" -ne 0 ]; then
        echo ""
        echo -e "${YELLOW}Static analysis failed — skipping tests.${NC}"
    else
        run_radon
        run_radon_mi
        run_cognitive_complexity
        run_cohesion
        run_tach
        run_vulture
        run_unit_tests
        if [ "$run_component_tests" -eq 1 ]; then
            run_component_tests
        fi
    fi

    end_time=$(now_ms)
    total_elapsed=$((end_time - start_time))

    print_summary
    exit "$overall_result"
}

main "$@"
