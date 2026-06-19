/*
import 'package:flutter_bloc/flutter_bloc.dart';

import 'filter_event.dart';
import 'filter_state.dart';


class FilterBloc extends Bloc<FilterEvent, FilterState> {
  FilterBloc() : super(FilterState()) {
    on<InitializeFilters>(_onInitializeFilters);
    on<ToggleCategorySelection>(_onToggleCategorySelection);
    on<ToggleBrandSelection>(_onToggleBrandSelection);
    on<ClearAllFilters>(_onClearAllFilters);
    on<ApplyFilters>(_onApplyFilters);
  }

  void _onInitializeFilters(
      InitializeFilters event,
      Emitter<FilterState> emit,
      ) {
    // Initialize with current state (keeps existing selections)
    emit(state);
  }

  void _onToggleCategorySelection(
      ToggleCategorySelection event,
      Emitter<FilterState> emit,
      ) {
    final newSelectedCategories = Set<int>.from(state.selectedCategorySlugs);

    if (newSelectedCategories.contains(event.categoryId)) {
      newSelectedCategories.remove(event.categoryId);
    } else {
      newSelectedCategories.add(event.categoryId);
    }

    emit(state.copyWith(
      selectedCategorySlugs: newSelectedCategories,
      isApplied: false,
    ));
  }

  void _onToggleBrandSelection(
      ToggleBrandSelection event,
      Emitter<FilterState> emit,
      ) {
    final newSelectedBrands = Set<int>.from(state.selectedBrandSlugs);

    if (newSelectedBrands.contains(event.brand)) {
      newSelectedBrands.remove(event.brandId);
    } else {
      newSelectedBrands.add(event.brandId);
    }

    emit(state.copyWith(
      selectedBrandSlugs: newSelectedBrands,
      isApplied: false,
    ));
  }

  void _onClearAllFilters(
      ClearAllFilters event,
      Emitter<FilterState> emit,
      ) {
    emit(FilterState());
  }

  void _onApplyFilters(
      ApplyFilters event,
      Emitter<FilterState> emit,
      ) {
    emit(state.copyWith(isApplied: true));
  }
}*/





import 'package:flutter_bloc/flutter_bloc.dart';

import 'filter_event.dart';
import 'filter_state.dart';

class FilterBloc extends Bloc<FilterEvent, FilterState> {
  FilterBloc() : super(FilterState()) {
    on<InitializeFilters>(_onInitializeFilters);
    on<ToggleCategorySelection>(_onToggleCategorySelection);
    on<ToggleBrandSelection>(_onToggleBrandSelection);
    on<ToggleAttributeValueSelection>(_onToggleAttributeValueSelection);
    on<ClearAllFilters>(_onClearAllFilters);
    on<ApplyFilters>(_onApplyFilters);
  }

  void _onInitializeFilters(
      InitializeFilters event,
      Emitter<FilterState> emit,
      ) {
    emit(state);
  }

  void _onToggleCategorySelection(
      ToggleCategorySelection event,
      Emitter<FilterState> emit,
      ) {
    final newSelected = Set<String>.from(state.selectedCategorySlugs);

    if (newSelected.contains(event.categorySlug)) {
      newSelected.remove(event.categorySlug);
    } else {
      newSelected.add(event.categorySlug);
    }

    emit(state.copyWith(
      selectedCategorySlugs: newSelected,
      isApplied: false,
    ));
  }

  void _onToggleBrandSelection(
      ToggleBrandSelection event,
      Emitter<FilterState> emit,
      ) {
    final newSelected = Set<String>.from(state.selectedBrandSlugs);

    if (newSelected.contains(event.brandSlug)) {
      newSelected.remove(event.brandSlug);
    } else {
      newSelected.add(event.brandSlug);
    }

    emit(state.copyWith(
      selectedBrandSlugs: newSelected,
      isApplied: false,
    ));
  }

  void _onToggleAttributeValueSelection(
      ToggleAttributeValueSelection event,
      Emitter<FilterState> emit,
      ) {
    final newSelected = Set<int>.from(state.selectedAttributeValueIds);

    if (newSelected.contains(event.attributeValueId)) {
      newSelected.remove(event.attributeValueId);
    } else {
      newSelected.add(event.attributeValueId);
    }

    emit(state.copyWith(
      selectedAttributeValueIds: newSelected,
      isApplied: false,
    ));
  }

  void _onClearAllFilters(
      ClearAllFilters event,
      Emitter<FilterState> emit,
      ) {
    emit(FilterState());
  }

  void _onApplyFilters(
      ApplyFilters event,
      Emitter<FilterState> emit,
      ) {
    emit(state.copyWith(isApplied: true));
  }
}