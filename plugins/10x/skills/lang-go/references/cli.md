# CLI Projects

## Directory Layout

Use slots only under the [layout ceiling](project-structure.md#the-layout-is-a-ceiling-not-a-default):
- `main.go`: imports commands; `cmd/root.go`: root/config; `cmd/command_helpers.go`: shared helpers.
- `cmd/<command>/<command>.go`: group registration; `<command><Action>.go`: actions (e.g. `userList.go`).
- `internal/<domain>/`: private logic/config.
- Public client only: `pkg/client/` interfaces/auth, `httpengine/` HTTP resources, `models/` API types; `pkg/utils/` normalization/formatting and `pkg/<feature>/` (saml/rest) only when independently reusable.
- `Makefile`: build/dev tasks; `env.sample`: config template; `README.md`: usage.

## Preferred Modules

`github.com/spf13/cobra` for commands, `github.com/spf13/viper` for env/files/flags, `github.com/olekukonko/tablewriter` for tables.

## Root Command Pattern

Set Cobra `Use`, one-line `Short`, and error-returning `PersistentPreRunE` for configuration. Registration/flag declaration may use existing command-file `init()` (`rootCmd.AddCommand`, `Flags().StringP("output", "o", "table", ...)`); this exception does not permit dependency wiring there. [Composition root](project-structure.md#composition-root-internalapp) owns dependencies and thin adapters.

## Exit Codes

0 success; 1 runtime error; 2 misuse/bad arguments. Commands return errors, never call `os.Exit`; main/top-level Execute handles stderr and process exit.

## Output Format

Human-readable tables/text go to stdout; errors to stderr. Support `--output json` for scripting, encoding the result with `json.NewEncoder(out).Encode(data)` and propagating errors; otherwise render the table. Gate: output streams, flags and exits match these contracts.
