/*
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:dkstore/l10n/app_localizations.dart';
import 'package:dkstore/screens/home_page/model/brands_model.dart';
import 'package:dkstore/screens/product_listing_page/bloc/filter_category/filter_category_bloc.dart';
import 'package:dkstore/screens/product_listing_page/bloc/filter_category/filter_category_state.dart';
import '../../config/constant.dart';
import 'package:dkstore/config/theme.dart';
import '../../screens/home_page/model/category_model.dart';
import '../../screens/product_listing_page/bloc/filter/filter_bloc.dart';
import '../../screens/product_listing_page/bloc/filter/filter_event.dart';
import '../../screens/product_listing_page/bloc/filter/filter_state.dart';
import '../../screens/product_listing_page/bloc/filter_brands/filter_brands_bloc.dart';
import '../../screens/product_listing_page/bloc/filter_category/filter_category_event.dart';
import '../../screens/product_listing_page/model/product_listing_type.dart';

enum FilterTab { categories, brands }

class CustomFilterBottomSheetTest extends StatefulWidget {
  final Function(List<CategoryData>, List<BrandData>) onApplyFilters;
  final ProductListingType listingType;
  final List<int> categoryIds;
  final List<int> brandsIds;

  const CustomFilterBottomSheetTest({
    super.key,
    required this.onApplyFilters,
    required this.listingType,
    required this.categoryIds,
    required this.brandsIds,
  });

  @override
  State<CustomFilterBottomSheetTest> createState() => _CustomFilterBottomSheetTestState();

  static void show({
    required BuildContext context,
    required Function(List<CategoryData>, List<BrandData>) onApplyFilters,
    required ProductListingType listingType,
    required List<int> categoryIds,
    required List<int> brandsIds,
  }) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 30),
            child: Center(
              child: GestureDetector(
                onTap: () => Navigator.of(context).pop(),
                child: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surface,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.1),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.close,
                    size: 20,
                    color: Colors.grey,
                  ),
                ),
              ),
            ),
          ),
          Expanded(
            child: CustomFilterBottomSheetTest(
              onApplyFilters: onApplyFilters,
              listingType: listingType,
              categoryIds: categoryIds,
              brandsIds: brandsIds,
            ),
          ),
        ],
      ),
    );
  }
}

class _CustomFilterBottomSheetTestState extends State<CustomFilterBottomSheetTest> {
  List<CategoryData> allCategories = [];
  List<BrandData> allBrands = [];

  FilterTab selectedTab = FilterTab.categories;

  @override
  void initState() {
    super.initState();
    if(widget.listingType == ProductListingType.category){
      selectedTab = FilterTab.brands;
    } else {
      selectedTab = FilterTab.categories;
    }
    context.read<FilterCategoryBloc>().add(FetchFilterCategories(context: context, categoryIds: widget.categoryIds));
    context.read<FilterBrandsBloc>().add(FetchFilterBrands(categorySlug: '', brandsIds: widget.brandsIds));
    context.read<FilterBloc>().add(InitializeFilters());
  }

  void _clearFilters() {
    context.read<FilterBloc>().add(ClearAllFilters());
  }

  void _applyFilters(FilterState filterState) {
    // Filter and return only selected items
    final selectedCategories = allCategories
        .where((category) => filterState.selectedCategoryIds.contains(category.id))
        .toList();

    final selectedBrands = allBrands
        .where((brand) => filterState.selectedBrandIds.contains(brand.id))
        .toList();

    context.read<FilterBloc>().add(ApplyFilters());
    widget.onApplyFilters(selectedCategories, selectedBrands);
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<FilterBloc, FilterState>(
      builder: (context, filterState) {
        return Container(
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(14.r),
              topRight: Radius.circular(14.r),
            ),
          ),
          child: Column(
            children: [
              // Header with total filter count
              _buildHeader(filterState),

              // Content area with tabs and list
              Expanded(
                child: Container(
                  margin: EdgeInsets.symmetric(horizontal: 8.w, vertical: 8.h),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      width: 1.0,
                      color: Theme.of(context).colorScheme.outlineVariant,
                    ),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Left side - Filter tabs
                      _buildFilterTabs(filterState),

                      // Right side - Filter options
                      Expanded(
                        child: selectedTab == FilterTab.categories
                            ? _buildCategoriesList(filterState)
                            : _buildBrandsList(filterState),
                      ),
                    ],
                  ),
                ),
              ),

              // Bottom buttons
              _buildBottomButtons(filterState),

              SizedBox(height: MediaQuery.of(context).padding.bottom),
            ],
          ),
        );
      },
    );
  }

  Widget _buildHeader(FilterState filterState) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 14.h),
      child: Row(
        children: [
          Text(
            AppLocalizations.of(context)!.filters,
            style: TextStyle(
              fontSize: isTablet(context) ? 24 : 16.sp,
              fontWeight: FontWeight.w600,
              fontFamily: AppTheme.fontFamily,
            ),
          ),
          if (filterState.hasActiveFilters) ...[
            SizedBox(width: 8.w),
            Container(
              padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 4.h),
              decoration: BoxDecoration(
                color: AppTheme.primaryColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12.r),
              ),
              child: Text(
                '${filterState.totalSelectedCount}',
                style: TextStyle(
                  fontSize: 12.sp,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.primaryColor,
                  fontFamily: AppTheme.fontFamily,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildFilterTabs(FilterState filterState) {
    return Container(
      padding: EdgeInsets.only(top: 8),
      width: 110.w,
      decoration: BoxDecoration(
        border: Border(
          right: BorderSide(
            color: Theme.of(context).colorScheme.outlineVariant,
            width: 1,
          ),
        ),
      ),
      child: Column(
        children: [
          if(widget.listingType != ProductListingType.category)
            _buildFilterTab(
              'Categories',
              FilterTab.categories,
              filterState.selectedCategoriesCount,
            ),
          if(widget.listingType != ProductListingType.brand)
            _buildFilterTab(
              'Brands',
              FilterTab.brands,
              filterState.selectedBrandsCount,
            ),
        ],
      ),
    );
  }

  Widget _buildFilterTab(
      String title,
      FilterTab tab,
      int selectedCount,
      ) {
    final isSelected = selectedTab == tab;

    return InkWell(
      onTap: () {
        setState(() {
          selectedTab = tab;
        });
      },
      child: Container(
        width: double.infinity,
        padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 12.h),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: isSelected ? [
              AppTheme.primaryColor.withValues(alpha: 0.2),
              AppTheme.primaryColor.withValues(alpha: 0.1),
              AppTheme.primaryColor.withValues(alpha: 0.05),
              Colors.transparent,
              Colors.transparent,
            ] : [Colors.transparent, Colors.transparent, Colors.transparent, Colors.transparent, Colors.transparent],
            stops: const [0.0, 0.2, 0.5, 0.8, 1.0],
          ),
          // color: isSelected
          //     ? Theme.of(context).colorScheme.surfaceContainerHighest
          //     : Colors.transparent,
          border: Border(
            left: BorderSide(
              color: isSelected ? AppTheme.primaryColor : Colors.transparent,
              width: 3,
            ),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: TextStyle(
                fontSize: 14,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                color: isSelected
                    ? AppTheme.primaryColor
                    : Theme.of(context).textTheme.bodyMedium?.color,
                fontFamily: AppTheme.fontFamily,
              ),
            ),
            if (selectedCount > 0) ...[
              SizedBox(height: 4.h),
              Container(
                padding: EdgeInsets.symmetric(horizontal: 6.w, vertical: 2.h),
                decoration: BoxDecoration(
                  color: AppTheme.primaryColor,
                  borderRadius: BorderRadius.circular(10.r),
                ),
                child: Text(
                  '$selectedCount',
                  style: TextStyle(
                    fontSize: isTablet(context) ? 14 : 10.sp,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                    fontFamily: AppTheme.fontFamily,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildBottomButtons(FilterState filterState) {
    return Container(
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        border: Border(
          top: BorderSide(
            color: Theme.of(context).colorScheme.outlineVariant,
            width: 1,
          ),
        ),
      ),
      child: Row(
        children: [
          // Clear Filters button
          Expanded(
            child: OutlinedButton(
              onPressed: filterState.hasActiveFilters ? _clearFilters : null,
              style: OutlinedButton.styleFrom(
                padding: EdgeInsets.symmetric(vertical: 12.h),
                side: BorderSide(
                  color: filterState.hasActiveFilters
                      ? AppTheme.primaryColor
                      : Colors.grey.shade300,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8.r),
                ),
                disabledForegroundColor: Colors.grey.shade400,
                disabledBackgroundColor: Colors.transparent,
              ),
              child: Text(
                'Clear Filters',
                style: TextStyle(
                  fontSize: isTablet(context) ? 18 : 14.sp,
                  fontWeight: FontWeight.w600,
                  color: filterState.hasActiveFilters
                      ? AppTheme.primaryColor
                      : Colors.grey.shade400,
                  fontFamily: AppTheme.fontFamily,
                ),
              ),
            ),
          ),
          SizedBox(width: 12.w),
          // Apply Filters button
          Expanded(
            child: ElevatedButton(
              onPressed: () => _applyFilters(filterState),
              style: ElevatedButton.styleFrom(
                padding: EdgeInsets.symmetric(vertical: 12.h),
                backgroundColor: AppTheme.primaryColor,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8.r),
                ),
              ),
              child: Text(
                'Apply Filters',
                style: TextStyle(
                  fontSize: isTablet(context) ? 18 : 14.sp,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                  fontFamily: AppTheme.fontFamily,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCategoriesList(FilterState filterState) {
    return BlocBuilder<FilterCategoryBloc, FilterCategoryState>(
      builder: (BuildContext context, FilterCategoryState state) {
        if (state is FilterCategoryLoading) {
          return Center(
            child: CircularProgressIndicator(
              color: AppTheme.primaryColor,
            ),
          );
        }

        if (state is FilterCategoryLoaded) {
          allCategories = state.categoryData
              .where((category) => category.status == 'active')
              .toList();

          if (allCategories.isEmpty) {
            return _buildEmptyState('No categories available');
          }

          return ListView.builder(
            padding: EdgeInsets.symmetric(vertical: 8.h),
            itemCount: allCategories.length,
            itemBuilder: (context, index) {
              final category = allCategories[index];
              final isSelected = filterState.selectedCategoryIds.contains(category.id);

              return _buildCategoryItem(category, isSelected);
            },
          );
        }

        if (state is FilterCategoryFailed) {
          return _buildErrorState('Failed to load categories');
        }

        return Center(
          child: CircularProgressIndicator(
            color: AppTheme.primaryColor,
          ),
        );
      },
    );
  }

  Widget _buildCategoryItem(CategoryData category, bool isSelected) {
    return CheckboxListTile(
      title: Text(
        category.title ?? 'Unknown',
        style: TextStyle(
          fontSize: 14,
          fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
          color: isSelected
              ? AppTheme.primaryColor
              : Theme.of(context).textTheme.bodyMedium?.color,
          fontFamily: AppTheme.fontFamily,
        ),
      ),
      value: isSelected,
      onChanged: (bool? value) {
        context.read<FilterBloc>().add(
          ToggleCategorySelection(category.id!),
        );
      },
      activeColor: AppTheme.primaryColor,
      checkColor: Colors.white,
      contentPadding: EdgeInsets.symmetric(horizontal: 16.w),
      dense: true,
      visualDensity: VisualDensity.compact,
    );
  }

  Widget _buildBrandsList(FilterState filterState) {
    return BlocBuilder<FilterBrandsBloc, FilterBrandsState>(
      builder: (BuildContext context, FilterBrandsState state) {
        if (state is FilterBrandsLoading) {
          return Center(
            child: CircularProgressIndicator(
              color: AppTheme.primaryColor,
            ),
          );
        }

        if (state is FilterBrandsLoaded) {
          allBrands = state.brandsData
              .where((brand) => brand.status == 'active')
              .toList();

          if (allBrands.isEmpty) {
            return _buildEmptyState('No brands available');
          }

          return ListView.builder(
            padding: EdgeInsets.symmetric(vertical: 8.h),
            itemCount: allBrands.length,
            itemBuilder: (context, index) {
              final brand = allBrands[index];
              final isSelected = filterState.selectedBrandIds.contains(brand.id);

              return _buildBrandItem(brand, isSelected);
            },
          );
        }

        if (state is FilterBrandsFailed) {
          return _buildErrorState('Failed to load brands');
        }

        return Center(
          child: CircularProgressIndicator(
            color: AppTheme.primaryColor,
          ),
        );
      },
    );
  }

  Widget _buildBrandItem(BrandData brand, bool isSelected) {
    return CheckboxListTile(
      title: Row(
        children: [
          // Brand Logo
          if (brand.logo != null && brand.logo!.isNotEmpty) ...[
            ClipRRect(
              borderRadius: BorderRadius.circular(4.r),
              child: Image.network(
                brand.logo!,
                width: 30.w,
                height: 30.w,
                fit: BoxFit.contain,
                errorBuilder: (context, error, stackTrace) {
                  return Container(
                    width: 30.w,
                    height: 30.w,
                    decoration: BoxDecoration(
                      color: Colors.grey[200],
                      borderRadius: BorderRadius.circular(4.r),
                    ),
                    child: Icon(
                      Icons.broken_image,
                      size: 16.sp,
                      color: Colors.grey[400],
                    ),
                  );
                },
              ),
            ),
            SizedBox(width: 12.w),
          ],
          // Brand Title
          Expanded(
            child: Text(
              brand.title ?? 'Unknown',
              style: TextStyle(
                fontSize: 14,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                color: isSelected
                    ? AppTheme.primaryColor
                    : Theme.of(context).textTheme.bodyMedium?.color,
                fontFamily: AppTheme.fontFamily,
              ),
            ),
          ),
        ],
      ),
      value: isSelected,
      onChanged: (bool? value) {
        context.read<FilterBloc>().add(
          ToggleBrandSelection(brand.id!),
        );
      },
      activeColor: AppTheme.primaryColor,
      checkColor: Colors.white,
      contentPadding: EdgeInsets.symmetric(horizontal: 16.w),
      dense: true,
      visualDensity: VisualDensity.compact,
    );
  }

  Widget _buildEmptyState(String message) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.filter_list_off,
            size: 48.sp,
            color: Colors.grey[400],
          ),
          SizedBox(height: 12.h),
          Text(
            message,
            style: TextStyle(
              fontSize: isTablet(context) ? 18 : 14.sp,
              color: Colors.grey[600],
              fontFamily: AppTheme.fontFamily,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState(String message) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.error_outline,
            size: 48.sp,
            color: Colors.red[300],
          ),
          SizedBox(height: 12.h),
          Text(
            message,
            style: TextStyle(
              fontSize: isTablet(context) ? 18 : 14.sp,
              color: Colors.red[400],
              fontFamily: AppTheme.fontFamily,
            ),
          ),
        ],
      ),
    );
  }
}







*/
/*

import 'dart:developer';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:dkstore/screens/category_list_page/bloc/all_category_bloc/all_category_bloc.dart';
import 'package:dkstore/screens/category_list_page/bloc/all_category_bloc/all_category_event.dart';
import 'package:dkstore/screens/category_list_page/bloc/all_category_bloc/all_category_state.dart';
import 'package:dkstore/screens/home_page/bloc/brands/brands_bloc.dart';
import 'package:dkstore/screens/home_page/bloc/sub_category/sub_category_bloc.dart';
import 'package:dkstore/screens/home_page/model/brands_model.dart';
import '../../config/constant.dart';
import 'package:dkstore/config/theme.dart';
import '../../screens/home_page/bloc/sub_category/sub_category_event.dart';
import '../../screens/home_page/bloc/sub_category/sub_category_state.dart';
import '../../screens/home_page/model/sub_category_model.dart';
import '../../screens/product_listing_page/bloc/filter/filter_bloc.dart';
import '../../screens/product_listing_page/bloc/filter/filter_event.dart';
import '../../screens/product_listing_page/bloc/filter/filter_state.dart';

enum FilterTab { categories, brands }

class CustomFilterBottomSheet extends StatefulWidget {
  final Function(List<SubCategoryData>, List<BrandsData>) onApplyFilters;

  const CustomFilterBottomSheet({
    super.key,
    required this.onApplyFilters,
  });

  @override
  State<CustomFilterBottomSheet> createState() => _CustomFilterBottomSheetState();

  static void show({
    required BuildContext context,
    required Function(List<SubCategoryData>, List<BrandsData>) onApplyFilters,
  }) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 30),
            child: Center(
              child: GestureDetector(
                onTap: () => Navigator.of(context).pop(),
                child: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surface,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.1),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.close,
                    size: 20,
                    color: Colors.grey,
                  ),
                ),
              ),
            ),
          ),
          Expanded(
            child: CustomFilterBottomSheet(
              onApplyFilters: onApplyFilters,
            ),
          ),
        ],
      ),
    );
  }
}

class _CustomFilterBottomSheetState extends State<CustomFilterBottomSheet> {
  List<SubCategoryData> tempCategories = [];
  List<BrandsData> tempBrands = [];


  FilterTab selectedTab = FilterTab.categories;

  @override
  void initState() {
    super.initState();
    context.read<AllCategoriesBloc>().add(FetchAllCategories());
    context.read<BrandsBloc>().add(FetchBrands(categorySlug: ''));
    context.read<FilterBloc>().add(InitializeFilters());
  }

  void _clearFilters() {
    context.read<FilterBloc>().add(ClearAllFilters());
  }

  void _applyFilters(FilterState filterState) {
    // Filter and return only selected items
    final selectedCategories = tempCategories
        .where((category) => filterState.selectedCategoryIds.contains(category.id))
        .toList();

    final selectedBrands = tempBrands
        .where((brand) => filterState.selectedBrandIds.contains(brand.id))
        .toList();

    context.read<FilterBloc>().add(ApplyFilters());
    widget.onApplyFilters(selectedCategories, selectedBrands);
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(14.r),
          topRight: Radius.circular(14.r),
        ),
      ),
      child: Column(
        children: [
          // Header
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 14.h),
            child: Row(
              children: [
                Text(
                  'Filters',
                  style: TextStyle(
                    fontSize: isTablet(context) ? 24 : 16.sp,
                    fontWeight: FontWeight.w600,
                    fontFamily: AppTheme.fontFamily,
                  ),
                ),
              ],
            ),
          ),

          // Divider(height: 1.h, color: Theme.of(context).colorScheme.outlineVariant),

          // Content area with tabs and list
          Expanded(
            child: Container(
              margin: EdgeInsets.symmetric(horizontal: 8.w, vertical: 8.h),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  width: 1.0,
                  color: Theme.of(context).colorScheme.outlineVariant
                )
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Left side - Filter tabs
                  Container(
                    padding: EdgeInsets.only(
                      top: 8
                    ),
                    width: 110.w,
                    decoration: BoxDecoration(
                      // color: Theme.of(context).colorScheme.surface,
                      border: Border(
                        right: BorderSide(
                          color: Theme.of(context).colorScheme.outlineVariant,
                          width: 1,
                        ),
                      ),
                    ),
                    child: Column(
                      children: [
                        _buildFilterTabDesign(
                          'Categories',
                          FilterTab.categories
                        ),
                        _buildFilterTabDesign(
                          'Brands',
                          FilterTab.brands
                        ),
                      ],
                    ),
                  ),

                  // Right side - Filter options
                  Expanded(
                    child: selectedTab == FilterTab.categories
                        ? _buildCategoriesList()
                        : _buildBrandsList(),
                  ),
                ],
              ),
            ),
          ),

          // Bottom buttons
          Container(
            padding: EdgeInsets.all(16.w),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              border: Border(
                top: BorderSide(
                  color: Theme.of(context).colorScheme.outlineVariant,
                  width: 1,
                ),
              ),
            ),
            child: Row(
              children: [
                // Clear Filters button
                Expanded(
                  child: OutlinedButton(
                    onPressed: filterState.hasActiveFilters ? _clearFilters : null,
                    style: OutlinedButton.styleFrom(
                      padding: EdgeInsets.symmetric(vertical: 12.h),
                      side: BorderSide(color: AppTheme.primaryColor),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8.r),
                      ),
                    ),
                    child: Text(
                      'Clear Filters',
                      style: TextStyle(
                        fontSize: isTablet(context) ? 18 : 14.sp,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.primaryColor,
                        fontFamily: AppTheme.fontFamily,
                      ),
                    ),
                  ),
                ),
                SizedBox(width: 12.w),
                // Apply Filters button
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => _applyFilters(context.read<FilterBloc>().state),
                    // onPressed),
                    style: ElevatedButton.styleFrom(
                      padding: EdgeInsets.symmetric(vertical: 12.h),
                      backgroundColor: AppTheme.primaryColor,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8.r),
                      ),
                    ),
                    child: Text(
                      'Apply Filters',
                      style: TextStyle(
                        fontSize: isTablet(context) ? 18 : 14.sp,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                        fontFamily: AppTheme.fontFamily,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),

          SizedBox(height: MediaQuery.of(context).padding.bottom),
        ],
      ),
    );
  }

  Widget _buildFilterTabDesign(
      String title,
      FilterTab tab,
      ) {
    final isSelected = selectedTab == tab;

    return InkWell(
      onTap: () {
        setState(() {
          selectedTab = tab;
        });
      },
      child: Container(
        width: double.infinity,
        padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 12.h),
        decoration: BoxDecoration(
          color: isSelected
              ? Theme.of(context).colorScheme.surfaceContainerHighest
              : Colors.transparent,
          border: Border(
            left: BorderSide(
              color: isSelected ? AppTheme.primaryColor : Colors.transparent,
              width: 3,
            ),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: TextStyle(
                fontSize: 14,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                color: isSelected
                    ? AppTheme.primaryColor
                    : Theme.of(context).textTheme.bodyMedium?.color,
                fontFamily: AppTheme.fontFamily,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterTabs(FilterState filterState) {
    return Container(
      padding: EdgeInsets.only(top: 8),
      width: 110.w,
      decoration: BoxDecoration(
        border: Border(
          right: BorderSide(
            color: Theme.of(context).colorScheme.outlineVariant,
            width: 1,
          ),
        ),
      ),
      child: Column(
        children: [
          _buildFilterTab(
            'Categories',
            FilterTab.categories,
            filterState.selectedCategoriesCount,
          ),
          _buildFilterTab(
            'Brands',
            FilterTab.brands,
            filterState.selectedBrandsCount,
          ),
        ],
      ),
    );
  }

  Widget _buildCategoriesList() {
    return BlocBuilder<AllCategoriesBloc, AllCategoriesState>(
      builder: (BuildContext context, AllCategoriesState state) {
        if (state is AllCategoriesLoading) {
          return Center(
            child: CircularProgressIndicator(
              color: AppTheme.primaryColor,
            ),
          );
        }

        if (state is AllCategoriesLoaded) {
          tempCategories = state.subCategoryData
              .where((category) => category.status == 'active')
              .toList();

          if (tempCategories.isEmpty) {
            return Center(
              child: Text(
                'No categories available',
                style: TextStyle(
                  fontSize: isTablet(context) ? 18 : 14.sp,
                  color: Colors.grey,
                  fontFamily: AppTheme.fontFamily,
                ),
              ),
            );
          }

          return ListView.builder(
            padding: EdgeInsets.symmetric(vertical: 8.h),
            itemCount: tempCategories.length,
            itemBuilder: (context, index) {
              final category = tempCategories[index];
              final isSelected = selectedCategoryIds.contains(category.id);

              return CheckboxListTile(
                title: Text(
                  category.title ?? 'Unknown',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                    color: isSelected
                        ? AppTheme.primaryColor
                        : Theme.of(context).textTheme.bodyMedium?.color,
                    fontFamily: AppTheme.fontFamily,
                  ),
                ),
                value: isSelected,
                onChanged: (bool? value) {
                  setState(() {
                    if (value == true) {
                      selectedCategoryIds.add(category.id!);
                    } else {
                      selectedCategoryIds.remove(category.id);
                    }
                  });
                },
                activeColor: AppTheme.primaryColor,
                checkColor: Colors.white,
                contentPadding: EdgeInsets.symmetric(horizontal: 16.w),
                dense: true,
                visualDensity: VisualDensity.compact,
              );
            },
          );
        }

        return const SizedBox.shrink();
      },
    );
  }

  Widget _buildBrandsList() {
    return BlocBuilder<BrandsBloc, BrandsState>(
      builder: (BuildContext context, BrandsState state) {
        if (state is BrandsLoading) {
          return Center(
            child: CircularProgressIndicator(
              color: AppTheme.primaryColor,
            ),
          );
        }

        if (state is BrandsLoaded) {
          tempBrands = state.brandsData
              .where((brand) => brand.status == 'active')
              .toList();

          if (tempBrands.isEmpty) {
            return Center(
              child: Text(
                'No brands available',
                style: TextStyle(
                  fontSize: isTablet(context) ? 18 : 14.sp,
                  color: Colors.grey,
                  fontFamily: AppTheme.fontFamily,
                ),
              ),
            );
          }

          return ListView.builder(
            padding: EdgeInsets.symmetric(vertical: 8.h),
            itemCount: tempBrands.length,
            itemBuilder: (context, index) {
              final brand = tempBrands[index];
              final isSelected = selectedBrandIds.contains(brand.id);

              return CheckboxListTile(
                title: Row(
                  children: [
                    // Brand Logo
                    if (brand.logo != null && brand.logo!.isNotEmpty) ...[
                      ClipRRect(
                        borderRadius: BorderRadius.circular(0.r),
                        child: Image.network(
                          brand.logo!,
                          width: 30.w,
                          height: 30.w,
                          fit: BoxFit.contain,
                          errorBuilder: (context, error, stackTrace) {
                            return Container(
                              width: 30.w,
                              height: 30.w,
                              decoration: BoxDecoration(
                                color: Colors.grey[200],
                                borderRadius: BorderRadius.circular(4.r),
                              ),
                              child: Icon(
                                Icons.broken_image,
                                size: 16.sp,
                                color: Colors.grey[400],
                              ),
                            );
                          },
                        ),
                      ),
                      SizedBox(width: 12.w),
                    ],
                    // Brand Title
                    Expanded(
                      child: Text(
                        brand.title ?? 'Unknown',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                          color: isSelected
                              ? AppTheme.primaryColor
                              : Theme.of(context).textTheme.bodyMedium?.color,
                          fontFamily: AppTheme.fontFamily,
                        ),
                      ),
                    ),
                  ],
                ),
                value: isSelected,
                onChanged: (bool? value) {
                  setState(() {
                    if (value == true) {
                      selectedBrandIds.add(brand.id!);
                    } else {
                      selectedBrandIds.remove(brand.id);
                    }
                  });
                },
                activeColor: AppTheme.primaryColor,
                checkColor: Colors.white,
                contentPadding: EdgeInsets.symmetric(horizontal: 16.w),
                dense: true,
                visualDensity: VisualDensity.compact,
              );
            },
          );
        }

        return const SizedBox.shrink();
      },
    );
  }
}*/

