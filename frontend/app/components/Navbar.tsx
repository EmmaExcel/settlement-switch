"use client";

import { Wallet } from "lucide-react";
import { ConnectButton } from "@rainbow-me/rainbowkit";

export default function Navbar() {
  return (
    <nav className="flex justify-between items-center border-b border-[#e5e5e5] p-4 bg-white">
      <div className="flex items-center gap-2">
        <div className="bg-purple-100 p-2 rounded-lg">
          <Wallet className="text-purple-600 w-5 h-5" />
        </div>
        <h1 className="text-lg font-semibold text-gray-800">Bridge</h1>
      </div>

      <div>
        <ConnectButton
          chainStatus="icon"
          accountStatus={{
            smallScreen: "avatar",
            largeScreen: "full",
          }}
          showBalance={false}
        />
      </div>
    </nav>
  );
}
