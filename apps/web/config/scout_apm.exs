# This configuration file is used for Scout APM.
# See our help docs at http://help.apm.scoutapp.com for more information.
# config/scout_apm.exs
use Mix.Config

config :scout_apm,
  name: "DomainScraper", # The app name that will appear within the Scout UI
  key: "lBRhDRwWJZvF4pV6VPo9"

config :phoenix, :template_engines,
  eex: ScoutApm.Instruments.EExEngine,
  exs: ScoutApm.Instruments.ExsEngine
