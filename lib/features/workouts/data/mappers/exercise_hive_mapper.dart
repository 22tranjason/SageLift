import '../../domain/models/exercise.dart';
import '../models/exercise_hive_model.dart';

/// Converts exercise persistence models into domain models.
extension ExerciseHiveMapper on ExerciseHiveModel {
  /// Creates the equivalent framework-independent [Exercise].
  Exercise toDomain() {
    return Exercise(
      id: id,
      name: name,
      category: ExerciseCategory.values[categoryIndex],
      primaryMuscleGroup: primaryMuscleGroupIndex == null
          ? null
          : MuscleGroup.values[primaryMuscleGroupIndex!],
      equipment: Equipment.values[equipmentIndex],
      instructions: instructions,
      notes: notes,
      isArchived: isArchived,
    );
  }
}

/// Converts exercise domain models into persistence models.
extension ExerciseDomainMapper on Exercise {
  /// Creates the Hive-specific representation of this exercise.
  ExerciseHiveModel toHiveModel() {
    return ExerciseHiveModel(
      id: id,
      name: name,
      categoryIndex: category.index,
      primaryMuscleGroupIndex: primaryMuscleGroup?.index,
      equipmentIndex: equipment.index,
      instructions: instructions,
      notes: notes,
      isArchived: isArchived,
    );
  }
}
