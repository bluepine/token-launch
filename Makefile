# help:
#     @echo "    init"
#     @echo "        Install dependencies."
#     @echo "    clean-pyc"
#     @echo "        Remove python artifacts."
#     @echo "    test"
#     @echo "        Run py.test"

init:
	pip install -r requirements.txt



clean-pyc:
	find . -name '*.pyc' -exec rm -f {} +
	find . -name '*.pyo' -exec rm -f {} +
	find . -name '*~' -exec rm -f {} +

test: clean-pyc
	python -m unittest discover tests.python