import argv
import clip
import clip/help
import clip/opt.{type Opt}

pub type Command {
  RunParameters(config: String)
  TestRulesParameters(config: String, extra_rules: String)
}

fn config_opt() -> Opt(String) {
  opt.new("config") |> opt.help("path to config file")
}

fn extra_rules_opt() -> Opt(String) {
  opt.new("rules")
  |> opt.help("path to file with list of additonal rules")
}

fn run_command() -> clip.Command(Command) {
  clip.command({
    use config <- clip.parameter
    RunParameters(config:)
  })
  |> clip.opt(config_opt())
}

fn test_rules_command() -> clip.Command(Command) {
  clip.command({
    use config <- clip.parameter
    use extra_rules <- clip.parameter

    TestRulesParameters(config:, extra_rules:)
  })
  |> clip.opt(config_opt())
  |> clip.opt(extra_rules_opt())
}

fn command() -> clip.Command(Command) {
  clip.subcommands([
    #("run", run_command()),
    #("test-rules", test_rules_command()),
  ])
}

pub fn parse() -> Result(Command, String) {
  command()
  |> clip.help(help.simple(
    "text_to_ledger",
    "Extract ledger information from text files",
  ))
  |> clip.run(argv.load().arguments)
}
