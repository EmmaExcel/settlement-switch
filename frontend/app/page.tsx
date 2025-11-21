import { Cable, Check, ChevronsLeftRightEllipsis, CircleCheckBig, Facebook, Gauge, Instagram, Percent, Twitter } from "lucide-react"
import Link from "next/link"

export default function Home(){
  const features = [
    {
      icon: Gauge ,
      title: "Blazing Fast Speeds",
      description: "Complete your cross-chain transfers in minutes, not hours, with our optimized bridging protocol.",
    },
    {
      icon: Check ,
      title: "Rock Solid Security",
      description: "Your assets are protected by industry-leading security audits and decentralized validation.",
    },
    {
      icon: Percent,
      title: "Expansive Network",
      description: "Access deep liquidity and a vast array of tokens across the most popular blockchain networks.",
    },
  ]


   const steps = [
    {
      icon: Cable ,
      title: "1. Connect Wallet",
      description: "Securely connect your preferred Web3 wallet to get started.",
    },
    {
      icon: ChevronsLeftRightEllipsis ,
      title: "2. Select Chains & Assets",
      description: "Choose the source and destination networks and the tokens you want to bridge.",
    },
    {
      icon: CircleCheckBig ,
      title: "3. Bridge Securely",
      description: "Confirm the transaction and receive your assets on the destination chain.",
    },
  ]


  const networks=[
    {
      icon: "https://assets.coingecko.com/coins/images/279/small/ethereum.png",
      name: "Ethereum",
    },
    {
      icon: "https://assets.coingecko.com/coins/images/4713/small/matic-token-icon.png",
      name: "Polygon",
    },
    {
      icon: "https://assets.coingecko.com/coins/images/16547/small/arbitrum.jpg",
      name: "Arbitrum",
    },
  ]


  return (
    <>
      {/* Hero Section */}
      <section className="w-full flex-1 flex justify-center py-8 md:py-12 lg:py-16 items-center min-h-[600px] md:min-h-[700px] lg:h-[800px] bg-[#f7f6f8] px-4">
        <div className="flex flex-col items-center gap-y-4 md:gap-y-6 max-w-6xl mx-auto">
          <h1 className="text-3xl sm:text-4xl md:text-5xl lg:text-6xl xl:text-7xl font-bold text-center z-10 leading-tight">
            Faster, Cheaper <br className="hidden sm:block"/> 
            Cross-chain Stable coins <br className="hidden sm:block"/> 
            Transfer
          </h1>
          <p className="text-center text-base sm:text-lg md:text-xl lg:text-2xl text-[#666666] max-w-xs sm:max-w-md md:max-w-2xl px-4">
            C8 is a decentralized settlement switch that routes stablecoin transactions across multiple blockchains using real-time Chainlink data.
          </p>
          <Link 
            href={"/bridge"} 
            className="bg-purple-600 text-white px-4 py-2 sm:px-6 sm:py-3 rounded-full text-base sm:text-lg font-medium cursor-pointer hover:scale-95 scale-100 hover:duration-200 duration-150 mt-2 md:mt-4"
          >
            Start bridging now
          </Link>
        </div>
      </section>

      {/* Features Section */}
      <section className="py-8 md:py-12 lg:py-16 flex justify-center bg-[#f7f6f8] px-4">
        <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-6 md:gap-8 w-full max-w-6xl">
          {features.map((feature, index) => (
            <div key={index} className="flex flex-1 gap-3 rounded-lg border border-border bg-card p-4 sm:p-6 min-h-[250px] md:h-72 flex-col items-center text-center justify-center">
              <feature.icon className="text-purple-800 w-6 h-6 sm:w-8 sm:h-8" />
              <div className="flex flex-col gap-1 sm:gap-2">
                <h2 className="text-base sm:text-lg font-bold leading-tight text-foreground">{feature.title}</h2>
                <p
                  className="text-sm sm:text-base font-normal leading-normal text-text-subtle px-2"
                  style={{ color: "var(--text-subtle)" }}
                >
                  {feature.description}
                </p>
              </div>
            </div>
          ))}
        </div>
      </section>

      {/* How It Works Section */}
      <section className="py-8 md:py-12 lg:py-16 flex flex-col justify-center items-center bg-[#f7f6f8] px-4">
        <div className="pb-8 md:pb-10 text-center">
          <h2 className="text-xl sm:text-2xl md:text-3xl font-bold leading-tight tracking-[-0.015em] px-4 pt-5 text-center text-foreground">
            How It Works
          </h2>
          <p className="text-text-subtle-light dark:text-text-subtle-dark max-w-xs sm:max-w-md md:max-w-xl mx-auto mt-2 text-sm sm:text-base px-4">
            Get started in three simple steps. Bridging has never been easier.
          </p>
        </div>
        <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-6 md:gap-8 w-full max-w-6xl">
          {steps.map((step, index) => (
            <div
              key={index}
              className="flex flex-1 gap-3 rounded-lg border border-border bg-card p-4 sm:p-6 min-h-[250px] md:h-72 flex-col items-center text-center justify-center"
            >
              <step.icon className="text-purple-800 w-6 h-6 sm:w-8 sm:h-8" />
              <div className="flex flex-col gap-1 sm:gap-2">
                <h2 className="text-base sm:text-lg font-bold leading-tight text-foreground">{step.title}</h2>
                <p
                  className="text-sm sm:text-base font-normal leading-normal text-text-subtle px-2"
                  style={{ color: "var(--text-subtle)" }}
                >
                  {step.description}
                </p>
              </div>
            </div>
          ))}
        </div>
      </section>

      {/* Supported Networks Section */}
      <section className="py-8 md:py-12 lg:py-16 flex flex-col justify-center items-center px-4">
        <h2 className="text-xl sm:text-2xl md:text-3xl font-bold leading-tight tracking-[-0.015em] px-4 pb-6 pt-5 text-center text-foreground">
          Supported Networks
        </h2>
        <div className="grid grid-cols-1 sm:grid-cols-2 gap-6 md:gap-8 w-full max-w-2xl">
          {networks.map((network, index) => (
            <div
              key={index}
              className="flex flex-1 gap-3 rounded-lg p-4 sm:p-6 flex-col items-center text-center"
            >
              <div className="flex flex-col gap-2 sm:gap-3 items-center">
                <img src={network.icon} alt={network.name} className="w-10 h-10 sm:w-12 sm:h-12" />
                <h2 className="text-sm sm:text-base leading-tight text-foreground">{network.name}</h2>
              </div>
            </div>
          ))}
        </div>
      </section>

      {/* Footer */}
      <footer className="border-t border-border mt-8 md:mt-16 py-6 md:py-8 px-4 md:px-6">
        <div className="flex flex-col md:flex-row justify-between items-center gap-4 md:gap-6 max-w-6xl mx-auto">
          <div className="text-xs sm:text-sm text-text-subtle text-center md:text-left" style={{ color: "var(--text-subtle)" }}>
            © 2025 Ordeal. All rights reserved.
          </div>
          <div className="flex flex-col sm:flex-row gap-4 sm:gap-6 text-center">
            <a
              className="text-text-subtle hover:text-primary transition-colors cursor-pointer text-xs sm:text-sm"
              href="#terms"
              style={{ color: "var(--text-subtle)" }}
            >
              Terms of Service
            </a>
            <a
              className="text-text-subtle hover:text-primary transition-colors cursor-pointer text-xs sm:text-sm"
              href="#privacy"
              style={{ color: "var(--text-subtle)" }}
            >
              Privacy Policy
            </a>
          </div>
          <div className="flex gap-3 sm:gap-4">
            <a className="text-text-subtle hover:text-primary transition-colors cursor-pointer" href="#twitter" title="Twitter">
              <Twitter className="w-4 h-4 sm:w-5 sm:h-5"/>
            </a>
            <a className="text-text-subtle hover:text-primary transition-colors cursor-pointer" href="#discord" title="Discord">
              <Instagram className="w-4 h-4 sm:w-5 sm:h-5"/>
            </a>
            <a className="text-text-subtle hover:text-primary transition-colors cursor-pointer" href="#telegram" title="Telegram">
              <Facebook className="w-4 h-4 sm:w-5 sm:h-5"/>
            </a>
          </div>
        </div>
      </footer>
    </>
  
  )
}