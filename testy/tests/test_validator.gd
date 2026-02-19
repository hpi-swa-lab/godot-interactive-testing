class_name TestValidator
extends RefCounted

static func validate(assertions: Array, id_map: Dictionary, comparison: SnapshotComparator.SnapshotComparison) -> TestReport:
	var report = TestReport.new()
	
	var diff_lookup = {}
	for delta in comparison.node_deltas:
		diff_lookup[delta.node_id] = delta
	
	for assertion_data in assertions:
		var original_id = int(assertion_data["node_id"])
		
		var entry = TestReportEntry.new()
		
		var mapped_id = id_map.get(original_id, -1)
		
		if mapped_id == -1:
			entry.node_id = original_id
			entry.fail("Node ID could not be mapped (Node missing in playback?)")
			
			var check = {
				"type": "meta",
				"name": "ID Mapping",
				"passed": false,
				"expected": str(original_id),
				"actual": "Missing"
			}
			entry.checks.append(check)
			report.add_entry(entry)
			continue
			
		entry.node_id = mapped_id
		
		var delta: SnapshotComparator.NodeDelta = diff_lookup.get(mapped_id)
		
		if delta == null:
			entry.fail("Node Data missing from Comparison")
			report.add_entry(entry)
			continue
			
		entry.node_name = delta.node_name
		entry.node_type = delta.node_type 
		
		if assertion_data.has("node_status"):
			var expected_status = assertion_data["node_status"]
			var actual_status = delta.status
			var passed = str(expected_status) == str(actual_status)
			
			if not passed:
				entry.fail("Status Mismatch")
			
			entry.checks.append({
				"type": "status",
				"name": "Node Status",
				"passed": passed,
				"expected": str(expected_status),
				"actual": str(actual_status)
			})

		if assertion_data.has("properties"):
			var expected_props = assertion_data["properties"]
			
			for prop_name in expected_props:
				var check = {
					"type": "property",
					"name": prop_name,
					"passed": true,
					"expected": "N/A",
					"actual": "N/A"
				}
				
				if not delta.properties.has(prop_name):
					check.passed = false
					check.expected = "Property Exists"
					check.actual = "Missing"
					entry.fail("Property Missing")
					entry.checks.append(check)
					continue
				
				var actual_val_container = delta.properties[prop_name]
				var expected_val_container = expected_props[prop_name]
				
				var is_expected_delta = (typeof(expected_val_container) == TYPE_DICTIONARY and expected_val_container.get("@is_property_delta", false) == true)
				var is_actual_delta = (actual_val_container is SnapshotComparator.PropertyDelta)
				
				var error = false
				
				if is_expected_delta:
					var exp_old = expected_val_container["old_value"]
					var exp_new = expected_val_container["new_value"]
					check.expected = "%s -> %s" % [exp_old, exp_new]
					
					if not is_actual_delta:
						error = true
						check.actual = "%s (Static)" % actual_val_container
						entry.fail("Expected Property Change, but Value was Static")
					else:
						var act_old = actual_val_container.old_value
						var act_new = actual_val_container.new_value
						check.actual = "%s -> %s" % [act_old, act_new]
						
						if not _compare_values(exp_old, act_old, id_map) or not _compare_values(exp_new, act_new, id_map):
							error = true
				
				else:
					check.expected = str(expected_val_container)
					
					if is_actual_delta:
						error = true
						var act_old = actual_val_container.old_value
						var act_new = actual_val_container.new_value
						check.actual = "%s -> %s (Unexpected Change)" % [act_old, act_new]
						entry.fail("Expected Static Value, but Property Changed")
					else:
						check.actual = str(actual_val_container)
						if not _compare_values(expected_val_container, actual_val_container, id_map):
							error = true
				
				if error:
					check.passed = false
					entry.fail("Property Mismatch")
				
				entry.checks.append(check)
		
		report.add_entry(entry)
		
	return report

static func _compare_values(expected, actual, id_map) -> bool:
	if typeof(expected) == TYPE_DICTIONARY and expected.has("@obj_ref"):
		var rec_id = int(expected["@obj_ref"])
		if rec_id <= 0:
			var actual_id = 0
			if typeof(actual) == TYPE_DICTIONARY and actual.has("@obj_ref"):
				actual_id = int(actual["@obj_ref"])
			return rec_id == actual_id
		var mapped_expected_id = id_map.get(rec_id, -1)
		var actual_id = 0
		if typeof(actual) == TYPE_DICTIONARY and actual.has("@obj_ref"):
			actual_id = int(actual["@obj_ref"])
		return mapped_expected_id == actual_id

	if typeof(expected) == TYPE_DICTIONARY and typeof(actual) == TYPE_DICTIONARY:
		if expected.size() != actual.size(): return false
		for key in expected:
			if not actual.has(key): return false
			if not _compare_values(expected[key], actual[key], id_map): return false
		return true

	if typeof(expected) == TYPE_ARRAY and typeof(actual) == TYPE_ARRAY:
		if expected.size() != actual.size(): return false
		for i in range(expected.size()):
			if not _compare_values(expected[i], actual[i], id_map): return false
		return true

	if (typeof(expected) == TYPE_FLOAT or typeof(expected) == TYPE_INT) and \
	   (typeof(actual) == TYPE_FLOAT or typeof(actual) == TYPE_INT):
		return is_equal_approx(float(expected), float(actual))
		
	if expected is Vector2 and actual is Vector2: return expected.is_equal_approx(actual)
	if expected is Vector3 and actual is Vector3: return expected.is_equal_approx(actual)
	if expected is Color and actual is Color: return expected.is_equal_approx(actual)

	return str(expected) == str(actual)
