class_name FormatUtils
extends RefCounted


static func stat(value: float) -> String:
	var formatted := "%.2f" % abs(value)

	# Remove unnecessary trailing zeros.
	formatted = formatted.rstrip("0").rstrip(".")

	if value > 0:
		return "+" + formatted
	elif value < 0:
		return "-" + formatted

	return "0"
