import Combine
import SwiftUI

struct WatchFlightInfoView: View {
    @ObservedObject var inflightInfoModel: WatchConnectivityManager
    
    var body: some View {
        VStack {
            if let error = inflightInfoModel.serviceError {
                VStack {
                    Text("\(error)")
                        .font(.caption)
                        .bold()
                        .foregroundColor(.red)
                        .lineLimit(2)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: true, vertical: true)
                    Button("Retry") {
                        
                    }
                    .padding()
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(10)
                }
                .padding(.horizontal, 10)
            } else {
                VStack {
                    Text(inflightInfoModel.timeAtOrigin)
                        .font(.title2)
                        .bold()
                    
                    Text(inflightInfoModel.originCity)
                        .font(.subheadline)
                        .lineLimit(2)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: true, vertical: true)
                }

                VStack {
                    
                    VStack {
                        Text(inflightInfoModel.timeToGo)
                            .font(.headline)
                        
                        Text("Landing")
                            .font(.caption2)
                            .foregroundColor(.white)
                    }
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(Rectangle()
                        .fill(Color.skyBlue)
                    )
                    
                    
                    Text(inflightInfoModel.timeAtDestination)
                        .font(.title2)
                        .bold()
                    
                    Text(inflightInfoModel.destinationCity)
                        .font(.subheadline)
                        .lineLimit(2)
                }
            }
        }
//        .padding(.vertical)
    }
}

#Preview {
    WatchFlightInfoView(inflightInfoModel: WatchConnectivityManager())
}

extension Color {
    static var skyBlue: Color {
        return Color(red: 35 / 255, green: 6 / 255, blue: 235 / 255)
    }
}
