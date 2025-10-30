// app/api/getRoute/route.ts
import { NextResponse } from "next/server";

export async function GET(req: Request) {
  try {
    const { searchParams } = new URL(req.url);

    const fromChain = searchParams.get("fromChain");
    const toChain = searchParams.get("toChain");
    const fromAddress =
      searchParams.get("fromAddress") ||
      "0x0000000000000000000000000000000000000000";
    const tokenSymbol = searchParams.get("token") || "USDC";
    const amount = searchParams.get("amount") || "1000000"; // default 1 USDC (6 decimals)

    // Token address mapping
    const tokenAddresses: Record<string, string> = {
      "1": "0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48", // Ethereum
      "137": "0x2791Bca1f2de4661ED88A30C99A7a9449Aa84174", // Polygon
      "10": "0x7F5c764cBc14f9669B88837ca1490cCa17c31607", // Optimism
      "42161": "0xFF970A61A04b1cA14834A43f5dE4533eBDDB5CC8", // Arbitrum
    };

    if (!fromChain || !toChain) {
      return NextResponse.json(
        { error: "Missing required query params: fromChain or toChain" },
        { status: 400 }
      );
    }

    const fromToken = tokenAddresses[fromChain] || tokenSymbol;
    const toToken = tokenAddresses[toChain] || tokenSymbol;

    const apiUrl = `https://li.quest/v1/quote?fromChain=${fromChain}&toChain=${toChain}&fromToken=${fromToken}&toToken=${toToken}&fromAmount=${amount}&fromAddress=${fromAddress}`;

    const res = await fetch(apiUrl);
    const data = await res.json();

    if (!data || !data.estimate) {
      return NextResponse.json(
        { error: "No route found or invalid response from LI.FI API" },
        { status: 404 }
      );
    }

    // Normalize fields to match frontend expectations
    const routes = [
      {
        bridge: data.tool || "Unknown Bridge",
        estimatedGasUSD: Number(data.estimate.gasCosts?.[0]?.amountUSD || 0),
        estimatedTimeSeconds: Number(data.estimate.executionDuration || 0),
      },
    ];

    return NextResponse.json({ success: true, routes }, { status: 200 });
  } catch (err) {
    console.error("Error fetching route:", err);
    return NextResponse.json(
      { success: false, error: "Internal Server Error" },
      { status: 500 }
    );
  }
}
