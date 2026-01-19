/// Abstract interface for Rive ViewModels providing lifecycle management.
///
/// This interface defines the common contract that all Rive ViewModels should
/// implement to ensure proper resource cleanup and disposal.
abstract class RiveViewModel {
  /// Returns true if this ViewModel has been disposed.
  bool get isDisposed;

  /// Disposes resources held by this ViewModel.
  ///
  /// This method should be called when the ViewModel is no longer needed
  /// to clean up resources like stream controllers, listeners, and the
  /// underlying Rive ViewModel instance.
  void dispose();
}
