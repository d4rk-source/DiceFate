import type { Metadata } from "next";
import "./globals.css";
import "@rainbow-me/rainbowkit/styles.css";
import { Providers } from "./providers";

export const metadata: Metadata = {
  title: "DiceFate - Provably Fair Dice Betting",
  description:
    "Bet on dice rolls with Chainlink VRF for provably fair randomness",
};

export default function RootLayout({
  children,
}: {
  children: React.ReactNode;
}) {
  return (
    <html lang="en">
      <body className="bg-dice-dark text-white">
        <Providers>{children}</Providers>
      </body>
    </html>
  );
}
