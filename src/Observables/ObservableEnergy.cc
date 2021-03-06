/////////////////////////////////////////////////////////////
// Copyright (C) 2003-2013  B. Clark, K. Esler, E. Brown   //
//                                                         //
// This program is free software; you can redistribute it  //
// and/or modify it under the terms of the GNU General     //
// Public License as published by the Free Software        //
// Foundation; either version 2 of the License, or         //
// (at your option) any later version.  This program is    //
// distributed in the hope that it will be useful, but     //
// WITHOUT ANY WARRANTY; without even the implied warranty //
// of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. //
// See the GNU General Public License for more details.    //
// For more information, please see the PIMC++ Home Page:  //
// http://code.google.com/p/pimcplusplus/                  //
/////////////////////////////////////////////////////////////
//Changed Something again
#include "ObservableEnergy.h"

// These are included for the new runtime 
// specification of energy observables 
// to compute; see below -John
#include "../Actions/MoleculeInteractionsClass.h"
#include "../Actions/EAMClass.h"
#include "../Actions/ST2WaterClass.h"
#include "../Actions/QMCSamplingClass.h"
#include "../Actions/DavidLongRangeClassYk.h"
#include "../Actions/ShortRangeOn_diagonal_displace_Class.h"


// Fix to include final link between link M and 0
void EnergyClass::Accumulate()
{
  NumSamples++;
  TimesCalled++;

  //Move the join to the end so we don't have to worry about permutations
  PathData.MoveJoin(PathData.NumTimeSlices() - 1);

  // Get the Full Weight from sign and importance sampling
  double FullWeight = CalcFullWeight();

  // Fill Energies Map
  PathData.Actions.Energy(energies);

  // Add energies to total
  double localSum = 0.0;
  for (std::list<string>::iterator labelIt = PathData.Actions.ActionLabels.begin(); labelIt != PathData.Actions.ActionLabels.end(); labelIt++) {
    localSum += energies[*labelIt] * FullWeight;
    ESum[*labelIt] += energies[*labelIt] * FullWeight;
    energies[*labelIt] = 0.0;
  }
  TotalSum += localSum;

  // Potentials
  double vShort, vLong, vExt;
  PathData.Actions.Potentials(vShort,vLong,vExt);
  VShortSum += vShort;
  VLongSum += vLong;
  VExtSum += vExt;

  // Energy Histogram
  double completeSum = PathData.Path.Communicator.Sum(localSum) /
                       (double) PathData.Path.TotalNumSlices;
  if (isnan(completeSum))
    cout << completeSum << " ERROR" << endl;
  EnergyHistogram.add(completeSum, 1.0);

  // Permutation Counting
  if(CountPerms) {
    vector<int> Cycles;
    int PermSector;
    PathData.Path.GetPermInfo(Cycles,PermSector);
    if (Path.Communicator.MyProc() == 0) {
      if (completeSum == 0) {
        cout << PermSector << " " << localSum << endl;
      }
      PermEnergy.push_back(completeSum);
      SectorCount.push_back(PermSector);
    }
  }

}


void EnergyClass::ShiftData(int NumTimeSlices)
{
  // Do nothing
}


void EnergyClass::WriteBlock()
{
  if (FirstTime) {
    FirstTime = false;
    int nPair = PathData.Actions.PairArray.size();
    Array<double,1> vTailSR(nPair), vTailLR(nPair);
    for (int iPair=0; iPair<nPair; iPair++) {
      vTailSR(iPair) = ((DavidPAClass *) (PathData.Actions.PairArray(iPair)))->Vimage;
      if (PathData.Path.DavidLongRange) {
        DavidLongRangeClassYk *lr = (DavidLongRangeClassYk *) (&(PathData.Actions.DavidLongRange));
        vTailLR(iPair) = 0.5 * lr->yk_zero(iPair) * PathData.Path.NumParticles();
      }
    }
    VTailSRVar.Write(vTailSR);
    VTailLRVar.Write(vTailLR);
    HistStart.Write(EnergyHistogram.startVal);
    HistEnd.Write(EnergyHistogram.endVal);
    NumPoints.Write(EnergyHistogram.NumPoints);
  }

  int nslices = PathData.Path.TotalNumSlices;
  double norm = 1.0 / ((double) NumSamples * (double) nslices);

  // Write out energies
  TotalVar.Write(Prefactor * PathData.Path.Communicator.Sum(TotalSum) * norm);
  VShortVar.Write(Prefactor * PathData.Path.Communicator.Sum(VShortSum) * norm);
  VLongVar.Write(Prefactor * PathData.Path.Communicator.Sum(VLongSum) * norm);
  VExtVar.Write(Prefactor * PathData.Path.Communicator.Sum(VExtSum) * norm);
  double localSum = 0.0;
  std::list<string>::iterator labelIt;
  for (labelIt = PathData.Actions.ActionLabels.begin(); labelIt != PathData.Actions.ActionLabels.end(); labelIt++) {
    EVar[*labelIt] -> Write(Prefactor * PathData.Path.Communicator.Sum(ESum[*labelIt]) * norm);
    ESum[*labelIt] = 0.0;
  }

  // Permutation Counting
  if (CountPerms && PathData.Path.Communicator.MyProc() == 0) {

    // Map out the PermEnergy vector
    map<int,vector<double> > PermEnergyMap;
    //map<int,int> SectorMap;
    double norm = Prefactor; // /((double) NumSamples);
    for (int i = 0; i < NumSamples; i++) {
      double energy = PermEnergy.back();
      int perm = SectorCount.back();
      if (PermEnergyMap.count(perm) == 0) {
        vector<double> tmpE;
        tmpE.push_back(energy*norm);
        PermEnergyMap.insert(pair<int,vector<double> >(perm,tmpE));
        //SectorMap.insert(pair<int,int>(perm,1));
      } else {
        PermEnergyMap[perm].push_back(energy*norm);
        //SectorMap[perm] += 1;
      }
      PermEnergy.pop_back();
      SectorCount.pop_back();
    }

    // Put the map into an array and write
    map<int,vector<double> >::iterator it;
    for(it = PermEnergyMap.begin(); it != PermEnergyMap.end(); it++) {
      Array<double,1> tmpPermEnergy(4);
      int perm = (*it).first;
      //double energy = (*it).second;
      vector<double> tmpE = (*it).second;
      double energy, err, N;
      GetStats(tmpE,energy,err,N);
      tmpPermEnergy(0) = perm;
      tmpPermEnergy(1) = energy;
      //tmpPermEnergy(1) = energy/SectorMap[perm];
      tmpPermEnergy(2) = N;
      //tmpPermEnergy(2) = SectorMap[perm];
      tmpPermEnergy(3) = err;
    //for (int i = 0; i < NumSamples; i++) {
    //  Array<double,1> tmpPermEnergy(2);
    //  tmpPermEnergy(0) = SectorCount.back();
    //  tmpPermEnergy(1) = PermEnergy.back();
    //  SectorCount.pop_back();
    //  PermEnergy.pop_back();
      PermEnergyVar.Write(tmpPermEnergy);
      PermEnergyVar.Flush();
    }

  }

  // Energy Histogram
  for (int i = 0; i < EnergyHistogram.histogram.size(); i++)
    EnergyHistogram.histogram[i] = Prefactor * EnergyHistogram.histogram[i] * norm * nslices;
  Array <double,1> EnergyHistogramTemp(&(EnergyHistogram.histogram[0]), shape(EnergyHistogram.histogram.size()), neverDeleteData);
  EnergyHistogramVar.Write(EnergyHistogramTemp);

  // Reset counters
  if (PathData.Path.Communicator.MyProc() == 0)
    IOSection.FlushFile();
  TotalSum = 0.0;
  VShortSum = 0.0;
  VLongSum = 0.0;
  VExtSum = 0.0;
  NumSamples = 0;
  EnergyHistogram.Clear();
}


void EnergyClass::Read(IOSectionClass & in)
{
  ObservableClass::Read(in);
  assert(in.ReadVar("Frequency", Freq));

  if (PathData.Path.Communicator.MyProc() == 0) {
    WriteInfo();
    IOSection.WriteVar("Type", "Scalar");
  }

  // Sign Tracking
  if(!in.ReadVar("TrackSign", TrackSign))
    TrackSign = 0;

  // Perm Sector Counting
  if(!in.ReadVar("CountPerms",CountPerms))
    CountPerms = 0;
  if(CountPerms) {
    int N = PathData.Path.NumParticles();
    // Maximum number of permutation sectors tracked
    int MaxNSectors;
    if(!in.ReadVar("MaxNSectors", MaxNSectors))
      MaxNSectors = 0; // 0 -> Track all sectors
    PathData.Path.SetupPermSectors(N,MaxNSectors);
    vector<int> Cycles;
    int PermSector;
    PathData.Path.GetPermInfo(Cycles,PermSector);
    if (PathData.Path.Communicator.MyProc() == 0)
      cout << PathData.Path.CloneStr << " Starting in Perm Sector " << PermSector << " of " << PathData.Path.PossPerms.size()-1 << endl;
  }

  // Energy Histogram
  double histStart = 0.0;
  double histEnd = 1.0;
  int histPoints = 1;
  in.ReadVar("HistStart", histStart);
  in.ReadVar("HistEnd", histEnd);
  in.ReadVar("HistPoints", histPoints);
  EnergyHistogram.Init(histPoints, histStart, histEnd);
  EnergyHistogramSum.resize(EnergyHistogram.histogram.size());

  // Setup Energies Map
  std::list<string>::iterator labelIt;
  for (labelIt = PathData.Actions.ActionLabels.begin(); labelIt != PathData.Actions.ActionLabels.end(); labelIt++) {
    energies.insert( std::pair<string,double>(*labelIt,0.0) );
    ObservableDouble* tmpVar = new ObservableDouble(*labelIt,IOSection,PathData.Path.Communicator);
    EVar.insert( std::pair<string,ObservableDouble*>(*labelIt,tmpVar) );
  }
}
