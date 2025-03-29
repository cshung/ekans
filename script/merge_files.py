import sys
from pathlib import Path

def merge_files(srcs, filename):
  files = list(Path(srcs).rglob('*.rkt'))

  if not files:
    return

  with open(filename, 'w', encoding = 'utf-8') as f_output:
    for file in files:
      with open(file, 'r', encoding = 'utf-8') as f_input:
        f_output.write(f_input.read())
      f_output.write('\n')

if __name__ == "__main__":
  if len(sys.argv) != 3:
    print("usage: python merge.py <directory> <output>")
    sys.exit(1)
    
  merge_files(sys.argv[1], sys.argv[2])
