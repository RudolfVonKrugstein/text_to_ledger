import argv
import clip.{type Command}
import clip/help
import clip/opt.{type Opt}

pub type Parameters {
  Parameters(config: String)
}

fn config_opt() -> Opt(String) {
  opt.new("config") |> opt.help("path to config file")
}

fn command() -> Command(Parameters) {
  clip.command({
    use config <- clip.parameter

    Parameters(config:)
  })
  |> clip.opt(config_opt())
}

pub fn parameters() -> Result(Parameters, String) {
  command()
  |> clip.help(help.simple(
    "text_to_ledger",
    "Extract ledger information from text files",
  ))
  |> clip.run(argv.load().arguments)
}
