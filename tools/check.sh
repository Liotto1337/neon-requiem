#!/usr/bin/env bash
# Full verification of the project:
#   1. tools/lint.py         — 40-line functions, no print(), single RNG, PURE modules, signals bus;
#   2. strict compile        — every script loaded with GDScript warnings raised to errors;
#   3. smoke test            — acceptance checklist played headless (tools/smoke/SmokeTest.tscn).
# Usage: GODOT=/path/to/Godot_v4.7 tools/check.sh   (add SOAK=1 for the 3-minute soak test)
set -euo pipefail
cd "$(dirname "$0")/.."
GODOT="${GODOT:-godot}"
export GODOT_SILENCE_ROOT_WARNING=1

python3 tools/lint.py

WARNINGS="unassigned_variable unassigned_variable_op_assign unused_variable unused_local_constant
unused_private_class_variable unused_parameter shadowed_variable shadowed_variable_base_class
shadowed_global_identifier unreachable_code unreachable_pattern standalone_expression
standalone_ternary incompatible_ternary untyped_declaration integer_division narrowing_conversion
int_as_enum_without_cast int_as_enum_without_match static_called_on_instance
confusable_local_declaration confusable_local_usage confusable_capture_reassignment
inference_on_variant native_method_override get_node_default_without_onready redundant_await
deprecated_keyword confusable_identifier"
{
  echo "[debug]"
  for warning in $WARNINGS; do echo "gdscript/warnings/${warning}=2"; done
} > override.cfg
trap 'rm -f override.cfg' EXIT
"$GODOT" --headless --path . --import > /dev/null 2>&1 || true
"$GODOT" --headless --path . res://tools/StrictCheck.tscn
echo "strict compile: OK"
rm -f override.cfg

"$GODOT" --headless --path . res://tools/smoke/SmokeTest.tscn
echo "smoke test: OK (report in user://smoke_report.txt)"
if [ "${SOAK:-0}" = "1" ]; then
  "$GODOT" --headless --path . res://tools/smoke/SoakTest.tscn
  echo "soak test: finished (report in user://soak_report.txt)"
fi
