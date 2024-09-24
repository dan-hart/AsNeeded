//
//  TripView.swift
//  AsNeeded
//
//  Created by Dan Hart on 12/16/23.
//

import SwiftUI

struct TripView: View {
    @StateObject var logbook = Logbook.shared
    
    @AppStorage("tripDays") var tripDays: Int = 7
    
    var nonTripDays: Double {
        Double(logbook.user.daysRemainingUntilNextRefillDate) - Double(tripDays)
    }
    
    var milligramsNeeded: Double {
        switch strategy {
        case .max:
            return Double(tripDays) * (logbook.user.plannedDailyDoseInMG * 2)
        case .uShaped:
            let travelDaysInMG = (logbook.user.plannedDailyDoseInMG * 2) * 2
            let remainingMGNeeded = Double(tripDays - 2) * 1.5
            return travelDaysInMG + remainingMGNeeded + (Double(tripDays) * logbook.user.plannedDailyDoseInMG)
        case .min:
            return Double(tripDays) * logbook.user.plannedDailyDoseInMG
        }
    }
    
    var remainingQuantityInMG: Double {
        return logbook.user.quantityInMG - ((logbook.user.daysRemainingUntilNextRefillDate) * logbook.user.plannedDailyDoseInMG)
    }
    
    var perNonTripDayMG: Double {
        logbook.user.dailyDoseInMG + ((remainingQuantityInMG - milligramsNeeded) / nonTripDays)
    }
    
    var remainingQuantityInDays: Double {
        return remainingQuantityInMG / logbook.user.dailyDoseInMG
    }
    
    var endOfCycleDailyTrimInMG: Double {
        return ((logbook.user.refillQuantityInMG + remainingQuantityInMG) / Constants.daysInCycle) - logbook.user.dailyDoseInMG
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
                    AsNeededMGView(value: $logbook.user.plannedDailyDoseInMG)
                        .padding(.bottom)
                    
                    Text("This works best if the trip is in the next \(logbook.user.daysRemainingUntilNextRefillDate.formatted()) days")
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
                    
                    
                    if perNonTripDayMG > logbook.user.plannedDailyDoseInMG {
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
        }
    }
}

#if DEBUG
#Preview {
    TripView()
}
#endif
