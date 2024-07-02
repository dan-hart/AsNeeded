//
//  TripView.swift
//  AsNeeded
//
//  Created by Dan Hart on 12/16/23.
//

import SwiftUI

struct TripView: View {
    @EnvironmentObject var userData: UserData
    
    @AppStorage("tripDays") var tripDays: Int = 7
    
    var nonTripDays: Double {
        Double(userData.daysRemainingUntilNextRefillDate ?? 0) - Double(tripDays)
    }
    
    var milligramsNeeded: Double {
        switch strategy {
        case .max:
            return Double(tripDays) * (userData.plannedDailyDoseInMG * 2)
        case .uShaped:
            let travelDaysInMG = (userData.plannedDailyDoseInMG * 2) * 2
            let remainingMGNeeded = Double(tripDays - 2) * 1.5
            return travelDaysInMG + remainingMGNeeded + (Double(tripDays) * userData.plannedDailyDoseInMG)
        case .min:
            return Double(tripDays) * userData.plannedDailyDoseInMG
        }
    }
    
    var remainingQuantityInMG: Double {
        return userData.quantityInMG - ((userData.daysRemainingUntilNextRefillDate ?? 0) * userData.plannedDailyDoseInMG)
    }
    
    var perNonTripDayMG: Double {
        userData.dailyDoseInMG + ((remainingQuantityInMG - milligramsNeeded) / nonTripDays)
    }
    
    var remainingQuantityInDays: Double {
        return remainingQuantityInMG / userData.dailyDoseInMG
    }
    
    var endOfCycleDailyTrimInMG: Double {
        return ((userData.refillQuantityInMG + remainingQuantityInMG) / Constants.daysInCycle) - userData.dailyDoseInMG
    }
    
    enum TitrationStrategy: String, CaseIterable {
        case max
        case uShaped
        case min
    }
    
    @AppStorage("strategy") var strategy: TitrationStrategy = .uShaped
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    Text("Planned Non-Trip Daily Dose")
                    AsNeededMGView(value: $userData.plannedDailyDoseInMG)
                        .padding(.bottom)
                    
                    Text("This works best if the trip is in the next \(userData.daysRemainingUntilNextRefillDate?.formatted() ?? "Unknown") days")
                        .font(.subheadline)
                    Stepper("Trip Days (\(tripDays))", value: $tripDays, in: 2...1000)
                    
                    HStack {
                        Text("Strategy")
                        Spacer()
                        Picker(selection: $strategy) {
                            ForEach(TitrationStrategy.allCases, id: \.self) {
                                Text($0.rawValue)
                            }
                        } label: {
                            Text("Strategy")
                        }
                    }
                    
                    
                    if perNonTripDayMG > userData.plannedDailyDoseInMG {
                        HStack {
                            Image(systemSymbol: .checkmarkCircleFill)
                                .foregroundStyle(.green)
                            Spacer()
                            Text("You will need \(milligramsNeeded.formatted()) MG for this trip, you will have \(remainingQuantityInMG.formatted()) MG left over.")
                        }
                    } else {
                        VStack(alignment: .leading, spacing: 16) {
                            HStack {
                                Image(systemSymbol: .xmarkCircleFill)
                                    .foregroundStyle(.red)
                                Text("You will need \(milligramsNeeded.formatted()) MG leftover at a minimum for this trip. \nRight now you will have \(remainingQuantityInMG.formatted()) MG left over.")
                            }
                            
                            Text("\(perNonTripDayMG.rounded(toPlaces: 2).formatted()) MG*")
                                .font(.title)
                            Text("*per non-trip day (\(nonTripDays.rounded(toPlaces: 2).formatted())) is suggested.")
                                .font(.subheadline)
                        }
                    }
                    
                    DisclaimerView()
                }
                .padding()
            }
            .navigationTitle("Trip")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    LogButtonView()
                }
                
                ToolbarItem {
                    QuickLogButton()
                }
            }
        }
    }
}

#Preview {
    TripView()
        .environmentObject(UserData.preview)
}
