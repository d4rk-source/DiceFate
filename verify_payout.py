# Verify corrected payout formula ensures house profitability

def verify_all_targets():
    """Verify house is profitable at all targets"""
    for target in range(2, 101):
        multiplier = 100.0 / (target - 1)
        final_payout = multiplier * 0.95
        win_prob = (target - 1) / 100.0
        lose_prob = (101 - target) / 100.0
        
        ev_profit = ((final_payout - 1) * win_prob) - lose_prob
        if ev_profit >= 0:
            return False, target
    return True, None

def show_details():
    """Show detailed breakdown"""
    print("=" * 90)
    print("HOUSE PROFITABILITY - CORRECTED FORMULA: Payout = 100/(targetNumber-1) * 0.95")
    print("=" * 90)
    print()
    print(f"{'Target':<8} {'Multiplier':<12} {'Payout':<10} {'Win%':<8} {'Player EV%':<15} {'House Edge':<12}")
    print("-" * 90)
    
    for target in [2, 5, 10, 25, 50, 75, 99, 100]:
        mult = 100.0 / (target - 1)
        payout = mult * 0.95
        win_prob = (target - 1) / 100.0
        lose_prob = (101 - target) / 100.0
        ev = ((payout - 1) * win_prob) - lose_prob
        house_edge = -ev * 100
        print(f"{target:<8} {mult:<12.4f} {payout:<10.4f} {win_prob*100:<8.1f} {ev*100:<15.2f}% {house_edge:<12.2f}%")

profitable, bad_target = verify_all_targets()
print()
if profitable:
    print("✅ HOUSE IS PROFITABLE AT ALL TARGETS (2-100)")
    print()
    show_details()
    print()
    print("=" * 90)
    print("All targets maintain approximately 5% house edge!")
    print("=" * 90)
else:
    print(f"❌ House unprofitable at target {bad_target}")

