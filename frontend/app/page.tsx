import { Cable, Check, ChevronsLeftRightEllipsis, CircleCheckBig, Facebook, Gauge, Instagram, Percent, Twitter } from "lucide-react"

export default function Home(){
  const features = [
    {
      icon: Gauge ,
      title: "Fast",
      description: "Complete your cross-chain swaps in minutes, not hours.",
    },
    {
      icon: Check ,
      title: "Secure",
      description: "Audited smart contracts and decentralized protocols protect your assets.",
    },
    {
      icon: Percent,
      title: "Low Fees",
      description: "Our optimized routing ensures you get the best rates with minimal cost.",
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
  ]


  return (
    <>
      <section className="w-full flex-1 flex justify-center py-6 items-center h-[800px] ">
     <div className="flex flex-col items-center gap-y-4">
       <h1 className="text-[78px] font-bold text-center z-10">Faster , Cheaper <br/> Cross-chain Stable coins <br/> Transfer</h1>
      <p className="text-center text-[24px] text-[#666666] max-w-2xl">C8 is a decentralized settlement switch that routes stablecoin transactions across multiple blockchains using real-time Chainlink data.</p>
      <button className="bg-purple-600 text-white px-6 py-3 rounded-full text-[18px] font-medium cursor-pointer hover:scale-95 scale-100 hover:duration-200 duration-150">Start bridging now</button>
     </div>
    </section>

     <section className="py-2 flex justify-center">
      <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-3 gap-8 p-0 max-w-5xl ">
        {features.map((feature, index) => (
          <div key={index} className="flex flex-1 gap-3 rounded-lg border border-border bg-card p-4 flex-col">
            <feature.icon className="text-purple-800 w-6 h-6" />
            <div className="flex flex-col gap-1">
              <h2 className="text-base font-bold leading-tight text-foreground">{feature.title}</h2>
              <p
                className="text-sm font-normal leading-normal text-text-subtle"
                style={{ color: "var(--text-subtle)" }}
              >
                {feature.description}
              </p>
            </div>
          </div>
        ))}
      </div>
    </section>

     <section className="py-2 flex flex-col justify-center items-center mt-16">
      <h2 className="text-2xl font-bold leading-tight tracking-[-0.015em] px-4 pb-6 pt-5 text-center text-foreground">
        How It Works
      </h2>
      <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-3 gap-8 p-0 max-w-5xl ">
        {steps.map((step, index) => (
          <div
            key={index}
            className="flex flex-1 gap-3 rounded-lg border border-border bg-card p-6 flex-col items-center text-center"
          >
           <step.icon className="text-purple-800 w-6 h-6" />
            <div className="flex flex-col gap-1">
              <h2 className="text-base font-bold leading-tight text-foreground">{step.title}</h2>
              <p
                className="text-sm font-normal leading-normal text-text-subtle"
                style={{ color: "var(--text-subtle)" }}
              >
                {step.description}
              </p>
            </div>
          </div>
        ))}
      </div>
    </section>

     <section className="py-2 flex flex-col justify-center items-center mt-16">
      <h2 className="text-2xl font-bold leading-tight tracking-[-0.015em] px-4 pb-6 pt-5 text-center text-foreground">
        Supported Networks
      </h2>
      <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-2 gap-8 p-0 max-w-5xl ">
        {networks.map((step, index) => (
          <div
            key={index}
            className="flex flex-1 gap-3 rounded-lg  p-6 flex-col items-center text-center"
          >
         
            <div className="flex flex-col gap-1 items-center">
              <img src={step.icon} alt={step.name} className="w-12 h-12" />
              <h2 className="text-base  leading-tight text-foreground">{step.name}</h2>
            </div>
          </div>
        ))}
      </div>
    </section>

    <footer className="border-t border-border mt-16 py-8 px-6">
      <div className="flex flex-col md:flex-row justify-between items-center gap-6">
        <div className="text-sm text-text-subtle text-center md:text-left" style={{ color: "var(--text-subtle)" }}>
          © 2025 Ordeal. All rights reserved.
        </div>
        <div className="flex gap-6">
          <a
            className="text-text-subtle hover:text-primary transition-colors cursor-pointer"
            href="#terms"
            style={{ color: "var(--text-subtle)" }}
          >
            Terms of Service
          </a>
          <a
            className="text-text-subtle hover:text-primary transition-colors cursor-pointer"
            href="#privacy"
            style={{ color: "var(--text-subtle)" }}
          >
            Privacy Policy
          </a>
        </div>
        <div className="flex gap-4 ">
          <a className="text-text-subtle hover:text-primary transition-colors cursor-pointer" href="#twitter" title="Twitter">
            <Twitter/>
          </a>
          <a className="text-text-subtle hover:text-primary transition-colors cursor-pointer" href="#discord" title="Discord">
            <Instagram/>
          </a>
          <a className="text-text-subtle hover:text-primary transition-colors cursor-pointer" href="#telegram" title="Telegram">
            <Facebook/>
          </a>
        </div>
      </div>
    </footer>
    </>
  
  )
}