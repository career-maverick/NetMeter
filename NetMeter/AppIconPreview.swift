//
//  AppIconPreview.swift
//  NetMeter
//
//  Created by Chiranjeevi Ram on 4/12/25.
//

import SwiftUI

struct AppIconPreview: View {
	var body: some View {
		ZStack {
			LinearGradient(gradient: Gradient(colors: [Color.blue, Color.purple]),
						  startPoint: .topLeading,
						  endPoint: .bottomTrailing)
				.frame(width: 1024, height: 1024)
			
			VStack(spacing: 50) {
				Image(systemName: "speedometer")
					.resizable()
					.aspectRatio(contentMode: .fit)
					.frame(width: 500, height: 500)
					.foregroundColor(.white)
				
				Text("NetMeter")
					.font(.system(size: 200, weight: .bold, design: .rounded))
					.foregroundColor(.white)
			}
		}
		.clipShape(RoundedRectangle(cornerRadius: 200))
	}
}

struct AppIconPreview_Previews: PreviewProvider {
	static var previews: some View {
		AppIconPreview()
	}
}
