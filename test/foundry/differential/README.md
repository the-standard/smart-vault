# New `SmartVaultYieldManager::_swapToRatio` implementation considerations

1) Safety catch-all: in `SmartVaultYieldManager::_deposit`, the call to `UniProxy::deposit` can fail if the balances in the contract are not at the same ratio as the Hypervisor requires. Here, a fail safe could be implemented to check that the ratio is correct by calling `UniProxy::.getDepositAmount`. Any excess balance could then be returned to the Smart Vault (`msg.sender`) before the call to `UniProxy::deposit`, guaranteeing that the deposit will always succeed.

2) The second branch (swap `B→A`) in the new `_swapToRatio()` is unnecessary. As the `SmartVaultYieldManager` shouldn't hold any tokens, and only `tokenA` is moved to the contract, there shouldn't be any `tokenB` present. In the unlikely scenario that there is more `tokenB` than required for the ratio, the surplus can be caught using the same catch-all as described above. This would mean some changes to the differential fuzz test as well.

The implementation is somewhat unclear due to stack management, so derivation of the maths is provided below:

## Derivation
### Without pool fees

Let's start without pool fees to describe the general maths.

Given:
1) amount $a$ of `tokenA`, and amount $b$ of `tokenB` in the contract.
2) price $p = \frac{\Delta a}{\Delta b}$
3) target ratio $r$ is $r = a/b_{mid}$, $b_{mid}$ is `_midRatio` in the code, hence is known.
4) target ratio is also target amount of a over target amount of b: $r = a_t / b_t$

#### swap A -> B

Gives: $a_t = a - \Delta a$ and $b_t = b + \Delta b$

thus the ratio:

$$
r = \frac{a - \Delta a}{b + \Delta b} => a - \Delta a = r ( b + \Delta b )
$$

we know $\Delta b = \frac{\Delta a}{p}$ thus:

$$
a - \Delta a = r (b + \frac{\Delta a}{p}) => a - \Delta a = rb + \frac{r\Delta a}{p}
$$

$$
-\Delta a - \frac{r\Delta a}{p} = rb - a => \Delta a + \frac{r\Delta a}{p} = a - rb
$$

$$
\Delta a (1 + \frac{r}{p}) = a - rb => \Delta a = \frac{a - rb}{1 + \frac{r}{p}}
$$

Sanity checking this, $a = 100$, $b= 100$, $p = 1/2$, $r = 1/2$:

$$
\Delta a = \frac{100 - 1/2 * 100}{1 + \frac{1/2}{1/2}} => \Delta a = \frac{100 - 50}{1 + 1} = 25
$$

Swapping `25 A` would give you `50 B` which would give the end result `75 A` and `150 B` which indeed was the ratio.

#### swap B -> A

$a_t = a + \Delta a$ and $b_t = b - \Delta b$

thus the ratio:

$$
r = \frac{a + \Delta a}{b - \Delta b} => a + \Delta a = r ( b - \Delta b )
$$

we know $\Delta b = \frac{\Delta a}{p}$ thus:

$$
a + \Delta a = r (b - \frac{\Delta a}{p}) => a + \Delta a = rb - \frac{r\Delta a}{p}
$$

$$
\Delta a + \frac{r\Delta a}{p} = rb - a
$$

$$
\Delta a( 1 + \frac{r}{p}) = rb - a => \Delta a = \frac{rb - a}{1 + \frac{r}{p}}
$$

Sanity checking $a = 100$, $b = 300$, $r$ and $p$ both $1/2$ again:


$$
\Delta a = \frac{1/2 * 300 - 100}{1 + 1} = 25
$$

To get `25 A` out, you need to provide `50 B` which would end up at `125 A`, `250 B` after the swap, which is the target ratio.

### With fees

Introducing pool fees changes the definition of the price, $p$.

For a swap A->B, the price for $\Delta a$ amount in is described as:

$$
p = \frac{\Delta a - \Delta a f}{\Delta b}
$$

where $f$ is the pool fee.

For a swap B->A, the price for $\Delta a$ amount out is similarly:

$$
p = \frac{\Delta a}{\Delta b - \Delta b f}
$$

#### Swap A -> B

Using the equation from above:

$$
r = \frac{a - \Delta a}{b + \Delta b} => a - \Delta a = r ( b + \Delta b )
$$

the new $\Delta b$ using fee will now be: $\Delta b = \frac{\Delta a(1-f)}{p}$ thus:

$$
a - \Delta a = r (b + \frac{\Delta a (1 - f)}{p})
$$

Using the same rearranging as above gives us a final equation for $\delta a$:

$$
 \Delta a = \frac{a - rb}{1 + \frac{r(1-f)}{p}}
$$

A quick sanity check tells us that increasing the fee $f$ here will decrease the denominator resulting in a higher $\Delta a$ which is what we expect (as more will be lost to the fee).

#### Swap B -> A

Using $p = \frac{\Delta a}{\Delta b (1-f)}$ gives us:

$$
a - \Delta a = r (b + \frac{\Delta a}{(1 - f)p})
$$

Which at the end gives us $\Delta a$ as:

$$
\Delta a = \frac{rb - a}{1 + \frac{r}{(1-f)p}}
$$

A quick sanity check tells us that increasing the fee $f$ here will increase the denominator resulting in a lower $\Delta a$ which is what we expect (as more will be lost to the fee, thus less out).
