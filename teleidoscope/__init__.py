from contextlib import suppress
import io
import ipaddress
import json
from typing import Dict, Generator, Tuple


__version__ = "0.0.5"


def remove_node(path: Dict):
    # Given a path, remove the top-level `node` key and value.
    # This is an artifact of an older threat proximity data format.
    with suppress(KeyError):
        path.pop("node")


def whitelist_node_info_keys(node: Tuple) -> Tuple:
    # Remove any extra keys from the node's info.
    ndef, info = node
    for key in list(info.keys()):
        if key not in ["iden", "props", "tags"]:
            info.pop(key)
    # The nested dictionary was modified so we can just return the original.
    return node


def tags_dict_to_list(node: Tuple) -> Tuple:
    # Convert the node's tags dictionary to a list if necessary.
    ndef, info = node
    if isinstance(info["tags"], Dict):
        tag_keys = list(info["tags"].keys())
        info["tags"] = tag_keys
    return (ndef, info)


def remove_non_leaf_tags(node: Tuple) -> Tuple:
    ndef, info = node
    tag_list = info["tags"]
    # Operate in-place.
    tag_list.sort()
    i = 0
    while True:
        if i >= len(tag_list) - 1:
            break
        # In the sorted tag list, if a tag is a substring of the
        # next tag, it is not a leaf.
        if tag_list[i] in tag_list[i + 1]:
            tag_list.pop(i)
        else:
            i += 1
    # The nested dictionary was modified so we can just return the original.
    return node


def stringify_ipv4_values(node: Tuple) -> Tuple:
    # Stringify `inet:ipv4` values for all nodes.
    ndef, info = node
    if ndef[0] != "inet:ipv4":
        return node

    try:
        ipv4 = ipaddress.IPv4Address(int(ndef[1]))
    except ValueError:
        ipv4 = ipaddress.IPv4Address(str(ndef[1]))

    ndef[1] = str(ipv4)

    # Tuples are immutable so we need to return a new tuple.
    return (ndef, info)


def process_path(path: dict):
    # Given a path, operate in-place to modify the data.
    remove_node(path)

    # Clean the data attached to each node in the path.
    new_path = []
    for node in path["path"]:
        new_node = node
        new_node = whitelist_node_info_keys(new_node)
        new_node = tags_dict_to_list(new_node)
        new_node = remove_non_leaf_tags(new_node)
        new_node = stringify_ipv4_values(new_node)
        new_path.append(new_node)
    path["path"] = new_path


def load_tpx_archive(stream: io.BytesIO) -> Generator[Dict, None, None]:
    # Assume that we have a stream of a gzipped json lines file.
    buf = b""
    lines = 0
    while stream.readable():
        buf += stream.read(io.DEFAULT_BUFFER_SIZE)
        if not buf:
            break

        # Attempt to extract lines from the current buffer.
        while True:
            pre, sep, post = buf.partition(b"\n")
            if not sep:
                break
            buf = post
            lines += 1

            try:
                line = pre.decode()
                entry = json.loads(line)
                process_path(entry)
                yield entry
            except json.JSONDecodeError:
                # Skip lines that could not be parsed.
                continue
