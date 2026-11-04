//
//  ChartComponent.swift
//  BazaarSimulator
//
//  Created by Rex Kenny Wirasantoso on 02/11/26.
//

import SwiftUI
import Charts

struct ProfitOverTime: Hashable {
    var date: Date
    var profit: Double
}


struct LineChart: View {
    let layout1: [ProfitOverTime] = [ProfitOverTime(date: Date.now, profit: 1.0), ProfitOverTime(date: Calendar.current.date(byAdding: .day, value: 1, to: Date.now)!, profit: 10.0), ProfitOverTime(date: Calendar.current.date(byAdding: .day, value: 2, to: Date.now)!, profit: 100.0)]
    let layout2: [ProfitOverTime] = [ProfitOverTime(date: Date.now, profit: 2.0), ProfitOverTime(date: Calendar.current.date(byAdding: .day, value: 1, to: Date.now)!, profit: 20.0), ProfitOverTime(date: Calendar.current.date(byAdding: .day, value: 2, to: Date.now)!, profit: 200.0)]
    
    var layout1MinMax: [ProfitOverTime] {
        guard let minItem = layout1.min(by: { $0.profit < $1.profit }),
              let maxItem = layout1.max(by: { $0.profit < $1.profit }) else { return [] }
        return Array(Set([minItem, maxItem])) // Set ensures uniqueness if min == max
    }
    
    var layout2MinMax: [ProfitOverTime] {
        guard let minItem = layout2.min(by: { $0.profit < $1.profit }),
              let maxItem = layout2.max(by: { $0.profit < $1.profit }) else { return [] }
        return Array(Set([minItem, maxItem]))
    }
    
    var body: some View {
        VStack{
            HStack(){
                Text("Flow Rate Through the day")
                Spacer()
                HStack{
                    HStack(alignment: .center){
                        Circle().foregroundStyle(.blue).frame(width: 8)
                        Text("Layout 1")
                    }.padding(.horizontal)
                    HStack(alignment: .center){
                        Circle().foregroundStyle(.green).frame(width: 8)
                        Text("Layout 2")
                    }.padding(.horizontal)
                }
            }
            Chart{
                ForEach(layout1, id: \.date) { item in
                    LineMark(
                        x: .value("Date", item.date),
                        y: .value("Profit A", item.profit),
                        series: .value("Company", "A")
                    )
                    .foregroundStyle(.blue)
                }
                ForEach(layout1MinMax, id: \.date) { item in
                    PointMark(
                        x: .value("Date", item.date),
                        y: .value("Profit A", item.profit)
                    )
                    .symbol(.diamond)
                    .symbolSize(60)
                    .foregroundStyle(.blue)
                }
                
                ForEach(layout2, id: \.date) { item in
                    LineMark(
                        x: .value("Date", item.date),
                        y: .value("Profit B", item.profit),
                        series: .value("Company", "B")
                    )
                    .foregroundStyle(.green)
                }
                ForEach(layout2MinMax, id: \.date) { item in
                    PointMark(
                        x: .value("Date", item.date),
                        y: .value("Profit A", item.profit)
                    )
                    .symbol(.diamond)
                    .symbolSize(60)
                    .foregroundStyle(.green)
                }
                
            }
            .chartYAxis {
                AxisMarks(position: .leading) { value in
                    // Change the grid line style here
                    AxisGridLine(stroke: StrokeStyle(lineWidth: 1)) // Dashed lines
                        .foregroundStyle(Color.gray.opacity(0.4))                 // Custom color & opacity
                    
                    AxisValueLabel() // Keeps the numerical labels visible
                }
            }
            
            .chartXAxis {
                AxisMarks { value in
                    AxisGridLine(stroke: StrokeStyle(lineWidth: 1.5))
                        .foregroundStyle(Color.blue.opacity(0))
                    
                    AxisValueLabel()
                }
            }
            .padding().glassEffect(in: .rect(cornerRadius: 12.0)).brightness(0.002)
        }.padding()
        
    }
}




#Preview {
    LineChart()
}
