from setuptools import setup, find_packages
import sys

needs_pytest = {"pytest", "test", "ptr"}.intersection(sys.argv)
pytest_runner = ["pytest-runner"] if needs_pytest else []

with open("README.md", "r") as fh:
    long_description = fh.read()

setup(
    name="teleidoscope",
    version="0.0.5",
    author="Eric Lee",
    author_email="elee@kududyn.com",
    description="Christmas Graph Visualizer",
    long_description=long_description,
    packages=find_packages(exclude=[
        "*.tests",
        "*.tests.*",
    ]),
    include_package_data=True,
    classifiers=["Private :: Do Not Upload"],

    entry_points={
        "console_scripts": [],
    },
    extras_require={
        "dev": [
            "nodeenv >= 1.3.2",
        ]
    },
    setup_requires=[] + pytest_runner,
    install_requires=[
        "aiofiles",
        "boto3",
        "fastapi >= 0.25.0",
        "uvicorn >= 0.7.1",
    ],
    tests_require=[
        "pytest",
        "pytest-cov",
        "pytest-flake8",
    ],
)
