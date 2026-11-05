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
    private static func time(_ hour: Int) -> Date {
        Calendar.current.date(bySettingHour: hour, minute: 0, second: 0, of: .now)!
    }

    let layout1: [ProfitOverTime] = [
        ProfitOverTime(date: LineChart.time(9), profit: 1.0),
        ProfitOverTime(date: LineChart.time(12), profit: 10.0),
        ProfitOverTime(date: LineChart.time(15), profit: 100.0)
    ]
    let layout2: [ProfitOverTime] = [
        ProfitOverTime(date: LineChart.time(9), profit: 2.0),
        ProfitOverTime(date: LineChart.time(12), profit: 20.0),
        ProfitOverTime(date: LineChart.time(15), profit: 200.0)
    ]

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
//                    .annotation(position: .bottom){
//                        if(item == layout1MinMax.first){
//                            Text("Minimum")
//                                .font(.caption)
//                                .padding(4)
//                                .background(Color.blue.opacity(0.4))
//                                .foregroundColor(.white)
//                                .cornerRadius(4)
//                        } else{
//                            Text("Peak")
//                                .font(.caption)
//                                .padding(4)
//                                .background(Color.blue.opacity(0.4))
//                                .foregroundColor(.white)
//                                .cornerRadius(4)
//                        }
//                        
//                    }
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
//                    .annotation(position: .top){
//                        if(item == layout2MinMax.first){
//                            Text("Minimum")
//                                .font(.caption)
//                                .padding(4)
//                                .background(Color.green.opacity(0.4))
//                                .foregroundColor(.white)
//                                .cornerRadius(4)
//                        } else{
//                            Text("Peak")
//                                .font(.caption)
//                                .padding(4)
//                                .background(Color.green.opacity(0.4))
//                                .foregroundColor(.white)
//                                .cornerRadius(4)
//                        }
//                        
//                    }
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
                AxisMarks(values: .stride(by: .hour)) { _ in
                    AxisGridLine(stroke: StrokeStyle(lineWidth: 1.5))
                        .foregroundStyle(Color.blue.opacity(0))
                    
                    AxisValueLabel(format: .dateTime.hour().minute())
                }
            }
            .padding()
        }.padding().glassEffect(in: .rect(cornerRadius: 12.0)).brightness(0.002)
        
    }
}




#Preview {
    LineChart()
}
