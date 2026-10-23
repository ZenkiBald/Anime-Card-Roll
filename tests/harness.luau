-- Shared by every test file in the bundle.
failures = 0
function check(cond, msg)
	if cond then
		print("PASS  " .. msg)
	else
		failures += 1
		print("FAIL  " .. msg)
	end
end
function near(a, b, tol)
	return math.abs(a - b) <= (tol or 1e-9)
end
