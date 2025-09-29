docs:
	forge doc --out docs/gen --serve --open --port 8453

docs-test:
	FOUNDRY_PROFILE=testdocs forge doc --out test/docs/gen --serve --open --port 84532

docs-clean:
	rm -rf docs/gen
	rm -rf test/docs/gen