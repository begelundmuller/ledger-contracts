# Main features

Model of a financial system with currencies, data feeds and a syntax for expressing compositional financial contracts. Main features:

- Many common contracts can be expressed
- Contracts may be gradually evaluated as time passes or new events occur
- Clear separation of tokens, data feeds, contract evaluation and contract execution
- `ContractEngine` encapsulates contract syntax and evaluation
- Multiple 'contract managers' can rely on the same 'contract engine'
- Contract managers handle an execution strategy. This project has a simple example of one, `ContractManager`. It handles routine tasks such as gathering signatures, executing transfers, and declaring defaults.

The contract syntax is based on a domain specific language for expressing financial contracts by [Bahr, Berthold and Elsman](http://hiperfit.dk/pdf/icfp15-contracts-final.pdf).
