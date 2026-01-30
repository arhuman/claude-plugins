# CLI Projects

## Directory Layout

- `main.go` - Application entry point that imports command packages
- `cmd/root.go` - Root command setup and configuration
- `cmd/command_helpers.go` - Shared command utilities and helpers
- `cmd/<command>/` - Command domain directories (e.g., user, group, token)
- `cmd/<command>/<command>.go` - Command group registration
- `cmd/<command>/<command><Action>.go` - Individual command implementations (e.g., userList.go, userGet.go)
- `internal/<domain>/` - Private application code and configuration
- `pkg/client/` - Client interface definitions and authentication
- `pkg/client/httpengine/` - HTTP client implementations for API resources
- `pkg/client/models/` - Data structures and API models
- `pkg/utils/` - Shared utilities (normalization, formatting, helpers)
- `pkg/<feature>/` - Feature-specific packages (e.g., saml, rest)
- `Makefile` - Build, test, and development commands
- `env.sample` - Environment configuration template
- `README.md` - Documentation and usage guide

## Preferred Modules

- `github.com/spf13/cobra` - CLI command framework
- `github.com/spf13/viper` - Configuration (env vars, config files, flags)
- `github.com/olekukonko/tablewriter` - Tabular output

## Root Command Pattern

```go
var rootCmd = &cobra.Command{
    Use:   "myapp",
    Short: "One-line description of myapp",
    PersistentPreRunE: func(cmd *cobra.Command, args []string) error {
        return initConfig()
    },
}

func Execute() {
    if err := rootCmd.Execute(); err != nil {
        fmt.Fprintln(os.Stderr, err)
        os.Exit(1)
    }
}
```

Subcommands are registered in `init()` of their own file:

```go
func init() {
    rootCmd.AddCommand(userCmd)
    userCmd.Flags().StringP("output", "o", "table", "Output format (table, json)")
}
```

## Exit Codes

- Exit 0: success
- Exit 1: general runtime error
- Exit 2: misuse / bad args

Never call `os.Exit` directly in cobra commands — return errors and let `main()` handle the exit.

## Output Format

- Human-readable output → stdout (tables, formatted text)
- Errors → stderr
- Support `--output json` flag for scripting

```go
func printOutput(cmd *cobra.Command, data any) error {
    format, _ := cmd.Flags().GetString("output")
    if format == "json" {
        return json.NewEncoder(os.Stdout).Encode(data)
    }
    // default: render table
    renderTable(data)
    return nil
}
```
