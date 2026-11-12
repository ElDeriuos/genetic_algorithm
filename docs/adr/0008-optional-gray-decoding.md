# 8. Gray decoding is optional, plain binary stays the default

Date: 2026-11-12 · Status: accepted

**Context.** With plain binary decoding the binary GA never reached the optimum of `sum((x-3)**2)` (10 variables, 16 bits each, 8 seeds, 3000 generations) on any range; with Gray decoding it needed 89 / 157 / 288 generations on ±20 / ±100 / ±1000. The literature mostly agrees (Caruana & Schaffer 1988; Whitley 1999), but not unanimously: binary can suit recombination-heavy search (Rothlauf), and binary has been shown to have no worse point locality than Gray (Shastri & Frachtenberg 2021).

**Decision.** `decode(bits, lower, upper, gray)` with optional `gray`, default `.false.`. Docs recommend `gray=.true.`.

**Why not default to Gray.** It would silently change what existing `decode` calls return, and the evidence for Gray is strong but problem-dependent.
