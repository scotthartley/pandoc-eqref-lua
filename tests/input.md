---
title: pandoc-eqref test document
header-includes:
    - \usepackage{mhchem}
---

# Display math equations

A simple linear equation:

$$x = y + z$$ {#eq:linear}

Einstein's mass-energy equivalence:

$$E = mc^2$$ {#eq:energy}

The quadratic formula:

$$x = \frac{-b \pm \sqrt{b^2 - 4ac}}{2a}$$ {#eq:quadratic}

# Chemical equations

Combustion of ethanol:

[CH3CH2OH + 3O2 -> 2CO2 + 3H2O]{.chem} {#eq:combustion}

A simple acid-base reaction:

[HCl + NaOH -> NaCl + H2O]{.chem} {#eq:acidbase}

Synthesis of ammonia (Haber process):

[N2 + 3H2 -> 2NH3]{.chem} {#eq:haber}

# Cross-references

Referring to display math: see @eq:linear, @eq:energy, and @eq:quadratic.

Referring to chemical equations: see @eq:combustion, @eq:acidbase, and @eq:haber.

Mixed reference in one sentence: @eq:energy gives the rest-mass energy, while
@eq:combustion shows the combustion of ethanol releasing that energy.

# Inline uses (must NOT be numbered)

The reaction [H2O]{.chem} produces water. The formula [CO2]{.chem} is carbon dioxide.
These inline uses should pass through to pandoc-chem-sub unchanged and must not
receive equation numbers.

A display math paragraph with no label is also left alone:

$$a^2 + b^2 = c^2$$

A chemical line with no label is left alone:

[Fe + S -> FeS]{.chem}
