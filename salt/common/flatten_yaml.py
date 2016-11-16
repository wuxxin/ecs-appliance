#!/usr/bin/env python3
import sys
import string
import collections

from shlex import quote

try:
    import yaml
except ImportError as e:
    print('ERROR: fatal, could not import yaml: {0}, try "apt install python3-yaml"'.format(e))
    sys.exit(1)


def usage():
    print('usage: {0} '.format(sys.argv[0])+
        '''(key[,key]*|.) [prefix [postfix]] < data.yml

read yaml from stdin, filter,
flatten (combine name space with "_") & upper case key names
output sorted keys to stdout using
{prefix}{KEY_NAME}={value}{postfix}

+ strings are modified with strip and shlex.quote
+ lists are converted to names using key_name_0, key_name_len as maxindex
+ bools are converted to repr(value).lower()
+ None is converted to an empty string

  ''')
    sys.exit(1)


def flatten(d, parent_key='', sep='_'):
    items = []

    if isinstance(d, collections.MutableMapping):
        for k, v in d.items():
            new_key = parent_key + sep + k if parent_key else k
            items.extend(flatten(v, new_key, sep).items())
        return dict(items)

    elif isinstance(d, (list, tuple)):
        for i, v in enumerate(d):
            new_key = parent_key + sep + str(i) if parent_key else str(i)
            items.extend(flatten(v, new_key, sep).items())
        items.extend([ (parent_key + sep + 'len', len(d)), ])
        return dict(items)

    else:
        if d is None:
            d = ''
        elif isinstance(d, str):
            d = quote(d.strip())
        elif isinstance(d, bool):
            d = repr(d).lower()
        return { parent_key: d }


def main():
    prefix = postfix = ''

    if len(sys.argv) < 2:
        usage()
    if len(sys.argv) >= 3:
        prefix = sys.argv[2]
    if len(sys.argv) >= 4:
        postfix = sys.argv[3]

    with sys.stdin as f:
        data = yaml.safe_load(f)

    for i in sys.argv[1].split(','):
        keyroot = ''
        if i == '.':
            result = sorted(flatten(data).items())
        elif i in data:
            result = sorted(flatten(data[i]).items())
            keyroot = i.upper()+ '_'
        else:
            print('Error: key "{}" not found in data'.format(i), file=sys.stderr)
            continue

        for key, value in result:
            print('{prefix}{key}={value}{postfix}'.format(
                prefix=prefix,
                key=keyroot+key.upper(),
                value=value,
                postfix=postfix))


if __name__ == '__main__':
    main()
