from eth_abi import encode
import argparse


def main(args):
    if args.function == "swap_to_ratio":
        delta_a, delta_b = swap_to_ratio(args)
        encode_and_print(delta_a, delta_b)


def swap_to_ratio(args):
    if not args.price or args.price == 0 or args.ratio == 0:
        return (0, 0)

    delta_a = 0
    delta_b = 0

    a = args.balance_a / 1e18
    b = args.balance_b / 1e18
    r = args.ratio / 1e18
    p = args.price / 1e18

    rb = r * b
    d = 1 + (r / p)

    if a > rb:
        delta_a = (a - rb) / d
    else:
        delta_a = (rb - a) / d

    return (int(delta_a * 1e18), int(delta_b * 1e18))


def encode_and_print(delta_a, delta_b):
    encoded_output = encode(["uint256", "uint256"], (delta_a, delta_b))
    ## append 0x for FFI parsing
    print("0x" + encoded_output.hex())


def parse_args():
    parser = argparse.ArgumentParser()
    parser.add_argument("function", choices=["swap_to_ratio"])
    parser.add_argument("--price", type=int)
    parser.add_argument("--ratio", type=int)
    parser.add_argument("--balance-a", type=int)
    parser.add_argument("--balance-b", type=int)
    return parser.parse_args()


if __name__ == "__main__":
    args = parse_args()
    main(args)
