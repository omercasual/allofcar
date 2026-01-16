class CarSelectionState {
  static final CarSelectionState _instance = CarSelectionState._internal();
  factory CarSelectionState() => _instance;
  CarSelectionState._internal();

  String? selectedCar1;
  String? selectedCar2;
  String? selectedBrand1;
  String? selectedBrand2;
  int? selectedYear1;
  int? selectedYear2;
  
  bool isNewCar = false;

  void clear() {
    selectedCar1 = null;
    selectedCar2 = null;
    selectedBrand1 = null;
    selectedBrand2 = null;
    selectedYear1 = null;
    selectedYear2 = null;
    isNewCar = false;
  }
}
