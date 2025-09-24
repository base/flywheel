docs:
	forge doc --out docs/gen --serve --open --port 8453

testdocs:
	FOUNDRY_PROFILE=testdocs forge doc --out test/docs/gen --serve --open --port 84532