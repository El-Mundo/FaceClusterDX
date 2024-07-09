//
//  T-SNE.swift
//  FaceCluster
//
//  Created by El-Mundo on 02/07/2024.
//

import Foundation

class T_SNE {
    private let distances: [Double]
    /// Input
    private let dimensions: Int
    private let n: Int
    private let perplexity: Double
    private let affinities: [Double]
    
    private var embeddings: [[Double]]?
    private var gains: [[Double]]?
    private var yStep: [[Double]]?
    private var iteration: Int = 0
    
    init(data: [[Double]], dimensions: Int, perplexity: Double) {
        let n = data.count
        if(n < 2) {
            fatalError(String(localized: "No enough data samples to perform dimension reduction"))
        } else if(dimensions < 2) {
            fatalError(String(localized: "Input vector must have more than 1 dimensions for dimension reduction"))
        }
        
        self.n = n
        let dist = T_SNE.getDistanceArray(data: data, inputDimensions: dimensions)
        self.dimensions = dimensions
        self.distances = dist
        self.perplexity = perplexity
        self.affinities = T_SNE.analyseAffinities(distances: distances, perplexity: perplexity, tol: 1e-4)
    }
    
    private func fill2DArray(size: Int, dimensions: Int, value: Double) -> [[Double]] {
        return Array<[Double]>(repeating: Array<Double>(repeating: value, count: dimensions), count: size)
    }
    
    class private func multiDimensionEuclidean(p1: [Double], p2: [Double], dimensions: Int) -> Double {
        var dist: Double = 0
        
        for i in 0..<dimensions {
            let diff = p1[i] - p2[i]
            dist += diff * diff
        }
        
        return dist
    }
    
    class private func getDistanceArray(data: [[Double]], inputDimensions: Int) -> [Double] {
        let n = data.count
        var distances = Array<Double>(repeating: 0, count: n*n)
        for i in 0..<n {
            for k in 0..<n {
                let dist = multiDimensionEuclidean(p1: data[i], p2: data[k], dimensions: inputDimensions)
                distances[i*n+k] = dist
                distances[k*n+i] = dist
            }
        }
        
        return distances
    }
    
    private func generateGaussianRandomNumbers(count: Int, mean: Double = 0.0, standardDeviation: Double = 1.0) -> [Double] {
        var gaussianNumbers: [Double] = []
        gaussianNumbers.reserveCapacity(count)
        
        while gaussianNumbers.count < count {
            let u1 = Double.random(in: 0.0..<1.0)
            let u2 = Double.random(in: 0.0..<1.0)
            
            let z0 = sqrt(-2.0 * log(u1)) * cos(2.0 * .pi * u2)
            let z1 = sqrt(-2.0 * log(u1)) * sin(2.0 * .pi * u2)
            
            gaussianNumbers.append(mean + z0 * standardDeviation)
            if gaussianNumbers.count < count {
                gaussianNumbers.append(mean + z1 * standardDeviation)
            }
        }
        
        return gaussianNumbers
    }
    
    private func initialiseEmbedding(size n: Int, dimensions: Int) -> [[Double]] {
        var embedding = Array(repeating: Array(repeating: 0.0, count: dimensions), count: n)
        for i in 0..<n {
            let randomNumbers = generateGaussianRandomNumbers(count: dimensions, mean: 0.0, standardDeviation: 0.1)
            embedding[i] = randomNumbers
        }
        return embedding
    }
    
    func transform(targetDimensions: Int, learningRate: Double, maxIterations: Int) -> [[Double]] {
        self.embeddings = self.initialiseEmbedding(size: n, dimensions: targetDimensions)
        self.gains = fill2DArray(size: n, dimensions: dimensions, value: 1)
        self.yStep = fill2DArray(size: n, dimensions: dimensions, value: 0)
        self.iteration = 0
        
        while iteration < maxIterations {
            forward(learningRate: learningRate, targetDimensions: targetDimensions)
        }
        
        return self.embeddings!
    }
    
    /*private func loadAffinities(distances: [[Double]], perplexity: Double) {
        var size = distances.count
        var dists = [Double]()
        for i in 0..<size {
            for j in 0..<size {
                var d = distances[i][j];
                dists[i * size + j] = d;
                dists[j * size + i] = d;
            }
        }
        analyseAffinities(distances: dists, perplexity: perplexity, tol: 1e-4);
        let _ = initialiseEmbedding(size: dists.count, dimensions: distances.count)
    }*/
    
    class private func analyseAffinities(distances: [Double], perplexity: Double, tol: Double) -> [Double] {
        let nf = Double(distances.count).squareRoot()
        let n = Int(floor(nf))
        
        let entropy = log(perplexity)
        var p = Array<Double>(repeating: 0, count: n*n)
        var rowP = Array<Double>(repeating: 0, count: n)
        
        for i in 0..<n {
            var prMin = -Double.infinity
            var prMax = Double.infinity
            var precision: Double = 1
            var completed = false
            let maxIterations = 50
            
            var iteration = 0
            
            while(!completed) {
                var psum = 0.0
                for j in 0..<n {
                    var pj: Double
                    if(i == j) {
                        pj = 0
                    } else {
                        pj = exp(-distances[i*n+j] * precision)
                    }
                    rowP[j] = pj
                    psum += pj
                }
                
                var hhere: Double = 0
                for j in 0..<n {
                    var pj: Double
                    if(psum == 0) {
                        pj = 0
                    } else {
                        pj = rowP[j] / psum
                    }
                    rowP[j] = pj
                    if(pj >  1e-7) {
                        hhere -= pj * log(pj)
                    }
                }
                    
                if(hhere > entropy) {
                    prMin = precision
                    if(prMax == .infinity) {
                        precision = precision * 2
                    } else {
                        precision = (precision + prMax) / 2
                    }
                } else {
                    prMax = precision
                    if(prMin == -.infinity) {
                        precision = precision / 2
                    } else {
                        precision = (precision + prMin) / 2
                    }
                }
                
                iteration += 1
                if(abs(hhere - entropy) < tol || iteration >= maxIterations) {
                    completed = true
                }
            }
            
            for j in 0..<n {
                p[i * n + j] = rowP[j]
            }
        }
        
        var pOut = Array<Double>(repeating: 0, count: n * n)
        let n2 = Double(n * 2)
        for i in 0..<n {
            for j in 0..<n {
                pOut[i * n + j] = max((p[i*n+j]+p[j*n+i])/n2, 1e-100)
            }
        }
        
        return pOut
    }
    
    private func getSign(v: Double) -> Int {
        if(v < 0) {
            return -1
        } else if(v > 0) {
            return 1
        } else {
            return 0
        }
    }
    
    private func forward(learningRate: Double, targetDimensions: Int) {
        iteration += 1
        print(iteration, "step")
        
        guard let cg = self.costGradient(self.embeddings!, iteration: self.iteration, targetDimensions: targetDimensions) else {
            return
        }
        let _ = cg.0
        let grad = cg.1
        
        var yMearn = Array<Double>(repeating: 0, count: targetDimensions)
        for i in 0..<n {
            for d in 0..<targetDimensions {
                let gid = grad[i][d]
                let sid = yStep![i][d]
                let gainid = gains![i][d]
                
                var newGain = getSign(v: gid) == getSign(v: sid) ? gainid * 0.8 : gainid + 0.2
                newGain = max(newGain, 0.01)
                self.gains![i][d] = newGain
                
                let momval = iteration < 250 ? 0.5 : 0.8
                let newSid = momval * sid - learningRate * newGain * grad[i][d]
                self.yStep![i][d] = newSid
                self.embeddings![i][d] += newSid
                yMearn[d] += self.embeddings![i][d]
            }
        }
        
        for i in 0..<n {
            for d in 0..<targetDimensions {
                self.embeddings![i][d] -= yMearn[d] / Double(n)
            }
        }
    }
    
    /// Returns cost and gradient of a given arrangement as a tuple
    private func costGradient(_ Y : [[Double]], iteration: Int, targetDimensions: Int) -> (Double, [[Double]])? {
        // A trick to help with local optima
        let pmul = iteration < 100 ? 4.0 : 1.0
        // Compute current Q distribution, unnormalized first
        let nn = n * n
        var qu = Array<Double>(repeating: 0, count: nn)
        var qsum = 0.0
        
        for i in 0 ..< n {
            for j in 0 ..< n {
                var dsum = 0.0
                for d in 0 ..< targetDimensions {
                    let dhere = Y[i][d] - Y [j][d]
                    dsum += dhere * dhere
                }
                let st = 1.0 / (1.0 + dsum) // Student t-distribution
                qu[i*n+j] = st
                qu[j*n+i] = st
                qsum += 2 * st
            }
        }
        // normalize Q distribution to sum to 1
        var Q = Array<Double>(repeating: 0, count: nn)
        for q in 0 ..< nn {
            Q[q] = ((qu[q] / qsum) > 1e-100) ? (qu[q] / qsum) : 1e-100
        }
        
        var cost = 0.0
        var grad = [[Double]]()
        for i in 0 ..< n {
            var gsum = Array<Double>(repeating: 0, count: targetDimensions)
            for j in 0 ..< n {
                cost += -affinities[i*n+j] * log(Q[i*n+j]) // accumulate cost (the non-constant portion at least...)
                let premult = 4 * (pmul * affinities[i*n+j] - Q[i*n+j]) * qu[i*n+j]
                for d in 0 ..< targetDimensions {
                    gsum[d] += premult * (Y[i][d] - Y[j][d])
                }
            }
            grad.append(gsum)
        }
        return (cost, grad)
    }
    
}
