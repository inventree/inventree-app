"""
Collect translation files into a single directory,
where they can be accessed by the flutter i18n library.

Translations provided from crowdin are located in subdirectories,
but we need the .arb files to appear in this top level directory
to be accessed by the app.

So, simply copy them here!

"""

import os
import shutil
import re
import json

def process_locale_file(filename):
    """
    Process a locale file after copying

    - Ensure the 'locale' matches
    """

    # Extract the locale name from the filename
    f = os.path.basename(filename)
    locale = re.search(r"^app\_(\w+)\.arb$", f).groups()[0]

    # TODO: Use JSON processing instead of manual
    # Need to work out unicode issues for this to work

    with open(filename, 'r', encoding='utf-8') as input_file:

        lines = input_file.readlines()

    with open(filename, 'w', encoding='utf-8') as output_file:
        # Using JSON processing would be simpler here,
        # but it does not preserve unicode data!
        for line in lines:
            if '@@locale' in line:
                new_line = f'    "@@locale": "{locale}"'

                if ',' in line:
                    new_line += ','
                
                new_line += '\n'

                line = new_line

            output_file.write(line)


def copy_locale_file(path):
    """
    Locate and copy the locale file from the provided directory
    """

    here = os.path.abspath(os.path.dirname(__file__))

    for f in os.listdir(path):

        src = os.path.join(path, f)
        dst = os.path.join(here, 'collected', f)

        if os.path.exists(src) and os.path.isfile(src) and f.endswith('.arb'):

            shutil.copyfile(src, dst)
            print(f"Copied file '{f}'")

            process_locale_file(dst)


if __name__ == '__main__':

    here = os.path.abspath(os.path.dirname(__file__))

    # Ensure the 'collected' output directory exists
    output_dir = os.path.join(here, 'collected')
    os.makedirs(output_dir, exist_ok=True)

    for item in os.listdir(here):

        # Ignore the output directory
        if item == 'collected':
            continue

        f = os.path.join(here, item)

        if os.path.exists(f) and os.path.isdir(item):
            copy_locale_file(f)

    # Ensure the translation source file ('app_en.arb') is copied also
    # Note that this does not require any further processing
    src = os.path.join(here, 'app_en.arb')
    dst = os.path.join(here, 'collected', 'app_en.arb')

    shutil.copyfile(src, dst)
