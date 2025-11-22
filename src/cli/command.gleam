import argv
import clip
import clip/help
import clip/opt.{type Opt}

pub type Command {
  RunParameters(config: String)
  TestEnrichersParameters(config: String, extra_enrichers: String)
}

fn config_opt() -> Opt(String) {
  opt.new("config") |> opt.help("path to config file")
}

fn extra_enrichers_opt() -> Opt(String) {
  opt.new("enrichers")
  |> opt.help("path to file with list of additonal enrichres")
}

fn run_command() -> clip.Command(Command) {
  clip.command({
    use config <- clip.parameter
    RunParameters(config:)
  })
  |> clip.opt(config_opt())
}

fn test_enrichers_command() -> clip.Command(Command) {
  clip.command({
    use config <- clip.parameter
    use extra_enrichers <- clip.parameter

    TestEnrichersParameters(config:, extra_enrichers:)
  })
  |> clip.opt(config_opt())
  |> clip.opt(extra_enrichers_opt())
}

fn command() -> clip.Command(Command) {
  clip.subcommands([
    #("run", run_command()),
    #("test-enrichers", test_enrichers_command()),
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
