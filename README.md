# Main features

Model of a financial system with currencies, data feeds and a DSL for writing contracts. Main features:

- Many common contracts can be expressed
- Contracts evaluate in accordance with a reduction semantics
- Clear separation of tokens, data feeds, contract evaluation and contract management
- Multiple 'contract managers' can rely on the same 'contract evaluator'
- Contract managers may automatically handle routine tasks such as
    - Gathering signatures
    - Executing transfers
    - Declaring defaults

The contract language is based on work [by Bahr, Berthold and Elsman](http://hiperfit.dk/pdf/icfp15-contracts-final.pdf).
