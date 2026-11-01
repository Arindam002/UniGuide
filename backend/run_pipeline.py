import os
import sys

sys.path.append(os.path.dirname(os.path.abspath(__file__)))

from run_processor import main as ingest_documents


def main():
    ingest_documents()


if __name__ == "__main__":
    main()