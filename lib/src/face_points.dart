class FacePoints {
  final int nFaces;
  final int nFacePoints;
  final List<int> points;
  final List<String> names;

  FacePoints(this.nFaces, this.nFacePoints, this.points, this.names);

  @override
  String toString() {
    return 'Faces: $nFaces,  points per faces: $nFacePoints,  '
        'names: $names,  n points: ${points.length}';
  }
}