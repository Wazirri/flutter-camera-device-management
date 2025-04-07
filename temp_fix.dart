      body: Column(
        children: [
          // Main grid taking all available space
          Container(
            width: size.width,
            height: availableHeight - (_totalPages > 1 ? paginationControlsHeight : 0),
            child: GridView.builder(
              padding: EdgeInsets.zero,
              physics: const NeverScrollableScrollPhysics(),
              shrinkWrap: true,
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: _gridColumns,
                childAspectRatio: aspectRatio, 
                crossAxisSpacing: 0,
                mainAxisSpacing: 0,
              ),
