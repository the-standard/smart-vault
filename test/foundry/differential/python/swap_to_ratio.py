from eth_abi import encode
import argparse


def main(args):
    if args.function == "swap_to_ratio":
        delta_a, delta_b = swap_to_ratio(args)
        encode_and_print(delta_a, delta_b)


def swap_to_ratio(args):
    if args.length < 4:
        return (0, 0)

    delta_a = (args.balance_a - args.mid_ratio * args.balance_b) / (1 + args.mid_ratio / args.price)
    delta_b = delta_a / args.price
    
    return (delta_a, delta_b)


def encode_and_print(delta_a, delta_b):
    encoded_output = encode(["uint256", "uint256"], (delta_a, delta_b))
    ## append 0x for FFI parsing
    print("0x" + encoded_output.hex())


def parse_args():
    parser = argparse.ArgumentParser()
    parser.add_argument("function", choices=["swap_to_ratio"])
    parser.add_argument("--price", type=int)
    parser.add_argument("--mid-ratio", type=int)
    parser.add_argument("--balance-a", type=int)
    parser.add_argument("--balance-b", type=int)
    return parser.parse_args()


if __name__ == "__main__":
    args = parse_args()
    main(args)
