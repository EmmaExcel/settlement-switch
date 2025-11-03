"use client";

import { useState } from "react";
import { Menu, X } from "lucide-react";
import { ConnectButton } from "@rainbow-me/rainbowkit";
import Link from "next/link";

export default function Navbar() {
  const [isMenuOpen, setIsMenuOpen] = useState(false);

  const toggleMenu = () => {
    setIsMenuOpen(!isMenuOpen);
  };

  return (
    <nav className="w-full max-w-7xl mx-auto mt-4 sm:mt-6 lg:mt-10 px-4 sm:px-6 lg:px-8">
      {/* Desktop and Tablet Layout */}
      <div className="flex justify-between items-center border-b border-[#dbd7d7] p-3 sm:p-4 rounded-full bg-white shadow-sm">
        {/* Logo */}
        <div className="flex items-center gap-2">
          <h1 className="text-lg sm:text-xl font-semibold text-gray-800">
            Ordeal
          </h1>
        </div>

        {/* Desktop Navigation Links */}
        <div className="hidden md:flex gap-x-6 font-medium">
          <Link 
            href="/" 
            className="text-gray-700 hover:text-gray-900 transition-colors duration-200"
          >
            Home
          </Link>
          <Link 
            href="/bridge" 
            className="text-gray-700 hover:text-gray-900 transition-colors duration-200"
          >
            Bridge
          </Link>
        </div>

        {/* Desktop Connect Button */}
        <div className="hidden md:block">
          <ConnectButton
            chainStatus="icon"
            accountStatus={{
              smallScreen: "avatar",
              largeScreen: "full",
            }}
            showBalance={false}
          />
        </div>

        {/* Mobile Menu Button */}
        <button
          onClick={toggleMenu}
          className="md:hidden p-2 rounded-lg hover:bg-gray-100 transition-colors duration-200"
          aria-label="Toggle menu"
        >
          {isMenuOpen ? (
            <X className="h-5 w-5 text-gray-700" />
          ) : (
            <Menu className="h-5 w-5 text-gray-700" />
          )}
        </button>
      </div>

      {/* Mobile Menu */}
      {isMenuOpen && (
        <div className="md:hidden mt-2 bg-white rounded-2xl border border-gray-200 shadow-lg overflow-hidden">
          <div className="px-4 py-3 space-y-3">
            {/* Mobile Navigation Links */}
            <div className="space-y-2">
              <Link 
                href="/" 
                className="block px-3 py-2 text-gray-700 hover:text-gray-900 hover:bg-gray-50 rounded-lg transition-colors duration-200"
                onClick={() => setIsMenuOpen(false)}
              >
                Home
              </Link>
              <Link 
                href="/bridge" 
                className="block px-3 py-2 text-gray-700 hover:text-gray-900 hover:bg-gray-50 rounded-lg transition-colors duration-200"
                onClick={() => setIsMenuOpen(false)}
              >
                Bridge
              </Link>
            </div>
            
            {/* Mobile Connect Button */}
            <div className="pt-3 border-t border-gray-100">
              <ConnectButton
                chainStatus="icon"
                accountStatus={{
                  smallScreen: "avatar",
                  largeScreen: "avatar",
                }}
                showBalance={false}
              />
            </div>
          </div>
        </div>
      )}
    </nav>
  );
}
